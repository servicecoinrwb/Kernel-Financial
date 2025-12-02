// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/* ========================================================================
   1. LIBRARIES & INTERFACES
   ========================================================================
*/

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        require(token.transfer(to, value), "SafeERC20: transfer failed");
    }
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        require(token.transferFrom(from, to, value), "SafeERC20: transferFrom failed");
    }
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require((value == 0) || (token.allowance(address(this), spender) == 0), "SafeERC20: non-zero allowance");
        require(token.approve(spender, value), "SafeERC20: approve failed");
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) { return msg.sender; }
}

// SECURITY: 2-Step Ownership Transfer
abstract contract Ownable is Context {
    address private _owner;
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error Unauthorized();
    error InvalidOwner();

    constructor() { _transferOwnership(_msgSender()); }

    modifier onlyOwner() { 
        if (_owner != _msgSender()) revert Unauthorized(); 
        _; 
    }

    function owner() public view virtual returns (address) { return _owner; }
    function pendingOwner() public view virtual returns (address) { return _pendingOwner; }
    
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert InvalidOwner();
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(_owner, newOwner);
    }

    function acceptOwnership() public virtual {
        if (_pendingOwner != _msgSender()) revert Unauthorized();
        _transferOwnership(_pendingOwner);
        _pendingOwner = address(0);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() { _status = _NOT_ENTERED; }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

interface IInvestorVault {
    function pushCapitalToKernel(uint256 amount) external;
    function registerRepayment(uint256 principal, uint256 profit) external;
}

/* ========================================================================
   2. INVESTOR VAULT ("THE SAFE") 
   - Timelocked Governance
   - Whitelisted Access
   - Slippage & Inflation Protection
   ========================================================================
*/

contract InvestorVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    
    // Core Addresses
    address public kernel;

    // Timelock State
    address public pendingKernel;
    uint256 public kernelUpdateTime;
    uint256 public constant TIMELOCK_DURATION = 48 hours;

    // Financial State
    uint256 public totalShares;
    uint256 public capitalInKernel; 

    // Access Control
    mapping(address => bool) public isWhitelisted;

    // User State
    mapping(address => uint256) public shares;
    mapping(address => uint256) public lastDepositTime;
    uint256 public constant LOCKUP = 24 hours;

    // Inflation Defense (+1 Offset)
    uint256 private constant VIRTUAL_OFFSET = 1;

    // Events
    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event Withdraw(address indexed user, uint256 assets, uint256 shares);
    event CapitalMovedToKernel(uint256 amount);
    event RepaymentReceived(uint256 principal, uint256 profit);
    event InvestorWhitelistUpdated(address indexed investor, bool status);
    event KernelUpgradeProposed(address indexed newKernel, uint256 unlockTime);
    event KernelUpgraded(address indexed oldKernel, address indexed newKernel);
    // Added for audit observability
    event AccountingWarning(uint256 expected, uint256 actual);

    // Errors
    error ZeroAmount();
    error UnauthorizedKernel();
    error LockedFunds();
    error InsufficientLiquidity();
    error SlippageExceeded();
    error NotWhitelisted(); 
    error TimelockActive();
    error NoPendingUpgrade();

    constructor(address _usdc) {
        usdc = IERC20(_usdc);
    }

    // --- Timelock Logic ---
    function proposeKernel(address _newKernel) external onlyOwner {
        require(_newKernel != address(0), "Zero Address");
        pendingKernel = _newKernel;
        kernelUpdateTime = block.timestamp + TIMELOCK_DURATION;
        emit KernelUpgradeProposed(_newKernel, kernelUpdateTime);
    }

    function upgradeKernel() external onlyOwner {
        if (pendingKernel == address(0)) revert NoPendingUpgrade();
        if (block.timestamp < kernelUpdateTime) revert TimelockActive();

        emit KernelUpgraded(kernel, pendingKernel);
        kernel = pendingKernel;
        
        pendingKernel = address(0);
        kernelUpdateTime = 0;
    }

    // --- Whitelist Logic ---
    function setInvestorStatus(address investor, bool status) external onlyOwner {
        isWhitelisted[investor] = status;
        emit InvestorWhitelistUpdated(investor, status);
    }

    modifier onlyKernel() {
        if (msg.sender != kernel) revert UnauthorizedKernel();
        _;
    }

    // --- View Functions ---
    function totalManagedAssets() public view returns (uint256) {
        return usdc.balanceOf(address(this)) + capitalInKernel;
    }

    // --- Deposit (Protected) ---
    function deposit(uint256 amount, uint256 minShares) external nonReentrant {
        if (!isWhitelisted[msg.sender]) revert NotWhitelisted();
        if (amount == 0) revert ZeroAmount();
        
        uint256 totalAssets = totalManagedAssets();
        
        // Math: (Amount * (TotalShares + 1)) / (TotalAssets + 1)
        uint256 sharesToMint = (amount * (totalShares + VIRTUAL_OFFSET)) / (totalAssets + VIRTUAL_OFFSET);

        if (sharesToMint < minShares) revert SlippageExceeded();

        usdc.safeTransferFrom(msg.sender, address(this), amount);
        
        shares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;
        lastDepositTime[msg.sender] = block.timestamp;

        emit Deposit(msg.sender, amount, sharesToMint);
    }

    // --- Withdraw (Protected) ---
    function withdraw(uint256 shareAmount, uint256 minAssets) external nonReentrant {
        if (shareAmount == 0) revert ZeroAmount();
        if (block.timestamp < lastDepositTime[msg.sender] + LOCKUP) revert LockedFunds();
        if (shares[msg.sender] < shareAmount) revert InsufficientLiquidity();

        uint256 totalAssets = totalManagedAssets();
        
        // Math: (Shares * (TotalAssets + 1)) / (TotalShares + 1)
        uint256 assetsToReturn = (shareAmount * (totalAssets + VIRTUAL_OFFSET)) / (totalShares + VIRTUAL_OFFSET);

        if (assetsToReturn < minAssets) revert SlippageExceeded();
        if (usdc.balanceOf(address(this)) < assetsToReturn) revert InsufficientLiquidity();

        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;

        usdc.safeTransfer(msg.sender, assetsToReturn);
        emit Withdraw(msg.sender, assetsToReturn, shareAmount);
    }

    // --- Kernel Interface ---
    function pushCapitalToKernel(uint256 amount) external onlyKernel {
        if (usdc.balanceOf(address(this)) < amount) revert InsufficientLiquidity();
        usdc.safeTransfer(kernel, amount);
        capitalInKernel += amount;
        emit CapitalMovedToKernel(amount);
    }

    function registerRepayment(uint256 principal, uint256 profit) external onlyKernel {
        if (capitalInKernel >= principal) {
            capitalInKernel -= principal;
        } else {
            // AUDIT FIX: Log the discrepancy for transparency before resetting
            emit AccountingWarning(capitalInKernel, principal);
            capitalInKernel = 0;
        }
        emit RepaymentReceived(principal, profit);
    }
}

/* ========================================================================
   3. KERNEL ("THE BRAIN")
   - Trade Finance Ready (Invoice Factoring)
   - Lending Logic
   - Fee Splitting
   ========================================================================
*/

contract Kernel is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    InvestorVault public vault;
    address public daoTreasury;

    uint256 public performanceFeeBps = 2000; // 20%
    mapping(address => bool) public whitelistedSolvers;
    mapping(address => uint256) public activePrincipal;

    // UPDATED: Now includes invoiceHash
    event LoanDisbursed(address indexed solver, uint256 amount, string invoiceHash);
    event LoanRepaid(address indexed solver, uint256 principal, uint256 fees);
    event FeesDistributed(uint256 investorShare, uint256 daoShare);

    error NotWhitelisted();
    error ActiveLoanExists();
    error InvalidRepayment();
    error InsufficientBalance();

    constructor(address _usdc, address _vault, address _treasury) {
        usdc = IERC20(_usdc);
        vault = InvestorVault(_vault);
        daoTreasury = _treasury;
    }

    function setSolver(address solver, bool status) external onlyOwner {
        whitelistedSolvers[solver] = status;
    }

    function setTreasury(address _treasury) external onlyOwner {
        daoTreasury = _treasury;
    }

    function setPerformanceFee(uint256 _bps) external onlyOwner {
        require(_bps <= 10000, "Max 100%");
        performanceFeeBps = _bps;
    }

    // --- Lending Operations ---

    // UPDATED: Now accepts invoiceHash string
    function deployCapital(
        address solver, 
        uint256 amount, 
        string calldata invoiceHash
    ) external onlyOwner nonReentrant {
        if (!whitelistedSolvers[solver]) revert NotWhitelisted();
        if (activePrincipal[solver] > 0) revert ActiveLoanExists();

        activePrincipal[solver] = amount;
        vault.pushCapitalToKernel(amount);
        usdc.safeTransfer(solver, amount);
        
        emit LoanDisbursed(solver, amount, invoiceHash);
    }

    function repayLoan(uint256 principal, uint256 fee) external nonReentrant {
        // Enforce repayment logic
        if (activePrincipal[msg.sender] != principal) revert InvalidRepayment();
        
        uint256 totalAmount = principal + fee;
        usdc.safeTransferFrom(msg.sender, address(this), totalAmount);
        
        activePrincipal[msg.sender] = 0;

        // Split Fees
        uint256 daoShare = 0;
        uint256 investorShare = fee;

        if (fee > 0) {
            daoShare = (fee * performanceFeeBps) / 10000;
            investorShare = fee - daoShare;
        }

        // Send DAO Portion
        if (daoShare > 0) {
            usdc.safeTransfer(daoTreasury, daoShare);
        }

        // Return Principal + Investor Yield to Vault
        uint256 toVault = principal + investorShare;
        usdc.safeTransfer(address(vault), toVault);
        vault.registerRepayment(principal, investorShare);

        emit LoanRepaid(msg.sender, principal, fee);
        emit FeesDistributed(investorShare, daoShare);
    }
}
