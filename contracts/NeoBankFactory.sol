// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Neo Bank System
 * @notice A flattened contract system containing the Factory, Checking Account logic,
 * and interfaces for the existing InvestorVault and Kernel ecosystem.
 */

// =============================================================
//                           LIBRARIES
// =============================================================

/**
 * @title Address
 * @dev Collection of functions related to the address type
 */
library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// =============================================================
//                           INTERFACES
// =============================================================

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

// Interface generated from provided InvestorVault ABI
interface IInvestorVault {
    function deposit(uint256 amount, uint256 minShares) external;
    function withdraw(uint256 shareAmount, uint256 minAssets) external;
    function shares(address account) external view returns (uint256);
    function capitalInKernel() external view returns (uint256);
    function totalManagedAssets() external view returns (uint256);
    function totalShares() external view returns (uint256);
    function kernel() external view returns (address);
    function usdc() external view returns (address);
}

// Interface generated from provided Kernel ABI
interface IKernel {
    function activePrincipal(address solver) external view returns (uint256);
    function deployCapital(address solver, uint256 amount, string calldata invoiceHash) external;
    function repayLoan(uint256 principal, uint256 fee) external;
    function whitelistedSolvers(address solver) external view returns (bool);
    function vault() external view returns (address);
}

// =============================================================
//                       SECURITY
// =============================================================

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

// =============================================================
//                      CHECKING ACCOUNT
// =============================================================

/**
 * @title CheckingAccount
 * @notice Represents a personal smart wallet for a single user.
 * @dev Acts as a middleman between the User, USDC, and the InvestorVault.
 */
contract CheckingAccount is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable owner;
    address public immutable factory;
    
    // The ecosystem addresses
    IERC20 public immutable usdc;
    IInvestorVault public immutable vault;
    address public immutable kernel;

    // Banking Features
    uint256 public dailyLimit;
    uint256 public currentDay;
    uint256 public spentToday;

    event DepositedToSavings(uint256 amount, uint256 sharesMinted);
    event WithdrawnFromSavings(uint256 sharesBurned, uint256 assetsReceived);
    event PaymentSent(address indexed to, uint256 amount);
    event FundsRecovered(address indexed token, uint256 amount);
    event DailyLimitChanged(uint256 newLimit);

    modifier onlyOwner() {
        require(msg.sender == owner, "CheckingAccount: Caller is not the owner");
        _;
    }

    constructor(
        address _owner, 
        address _usdc, 
        address _vault, 
        address _kernel
    ) {
        owner = _owner;
        factory = msg.sender;
        usdc = IERC20(_usdc);
        vault = IInvestorVault(_vault);
        kernel = _kernel;
    }

    // Allow receiving ETH (so it can be recovered)
    receive() external payable {}

    // -------------------------------------------------------------
    // Banking / Payments
    // -------------------------------------------------------------

    /**
     * @notice Helper to enforce daily limits
     */
    function _checkAndUpdateLimit(uint256 amount) internal {
        if (dailyLimit > 0) {
            uint256 today = block.timestamp / 1 days;
            if (today > currentDay) {
                currentDay = today;
                spentToday = 0;
            }
            require(spentToday + amount <= dailyLimit, "CheckingAccount: Daily spending limit exceeded");
            spentToday += amount;
        }
    }

    /**
     * @notice Send USDC to another address (Payment).
     * @param to The recipient address.
     * @param amount The amount of USDC to send.
     */
    function pay(address to, uint256 amount) external onlyOwner nonReentrant {
        _checkAndUpdateLimit(amount);
        
        require(usdc.balanceOf(address(this)) >= amount, "CheckingAccount: Insufficient funds");
        usdc.safeTransfer(to, amount);
        emit PaymentSent(to, amount);
    }

    /**
     * @notice Set a daily spending limit in USDC units (e.g. 1000000000 for 1000 USDC).
     * @param _limit The new limit. Set to 0 to disable.
     */
    function setDailyLimit(uint256 _limit) external onlyOwner {
        dailyLimit = _limit;
        emit DailyLimitChanged(_limit);
    }

    /**
     * @notice Batch execute multiple calls (Multicall).
     * @dev Check logic added to prevent bypassing daily limits via batch execution.
     */
    function executeBatch(
        address[] calldata targets, 
        bytes[] calldata datas, 
        uint256[] calldata values
    ) external onlyOwner nonReentrant {
        require(targets.length == datas.length && targets.length == values.length, "CheckingAccount: Length mismatch");
        
        for (uint256 i = 0; i < targets.length; i++) {
            // Check if this call is targeting the USDC contract
            if (targets[i] == address(usdc)) {
                bytes4 selector;
                if (datas[i].length >= 4) {
                    selector = bytes4(datas[i][0]) | (bytes4(datas[i][1]) >> 8) | (bytes4(datas[i][2]) >> 16) | (bytes4(datas[i][3]) >> 24);
                }
                
                // Handle transfer(address,uint256)
                if (selector == IERC20.transfer.selector) {
                    if (datas[i].length >= 68) {
                        (, uint256 amount) = abi.decode(datas[i][4:], (address, uint256));
                        _checkAndUpdateLimit(amount);
                    }
                }
                // Handle transferFrom(address,address,uint256) - Only if funds come FROM this wallet
                else if (selector == IERC20.transferFrom.selector) {
                    if (datas[i].length >= 100) {
                        (address from, , uint256 amount) = abi.decode(datas[i][4:], (address, address, uint256));
                        if (from == address(this)) {
                            _checkAndUpdateLimit(amount);
                        }
                    }
                }
                // Handle approve(address,uint256) - Treat approval as potential spend
                else if (selector == IERC20.approve.selector) {
                    if (datas[i].length >= 68) {
                        (, uint256 amount) = abi.decode(datas[i][4:], (address, uint256));
                        _checkAndUpdateLimit(amount);
                    }
                }
                // Handle increaseAllowance(address,uint256) - Prevent bypass
                else if (selector == 0x39509351) { 
                    if (datas[i].length >= 68) {
                        (, uint256 amount) = abi.decode(datas[i][4:], (address, uint256));
                        _checkAndUpdateLimit(amount);
                    }
                }
            }

            (bool success, ) = targets[i].call{value: values[i]}(datas[i]);
            require(success, "CheckingAccount: Batch call failed");
        }
    }

    // -------------------------------------------------------------
    // Savings (InvestorVault Integration)
    // -------------------------------------------------------------

    /**
     * @notice Moves funds from Checking (this contract) into the InvestorVault.
     * @param amount Amount of USDC to invest.
     * @param minShares Slippage protection (minimum shares to receive).
     */
    function depositToSavings(uint256 amount, uint256 minShares) external onlyOwner nonReentrant {
        require(usdc.balanceOf(address(this)) >= amount, "CheckingAccount: Insufficient funds to invest");

        // 1. Approve Vault to spend USDC (Safe Approve handles non-standard returns)
        usdc.safeApprove(address(vault), 0); // Reset allowance first to be safe with USDT-like tokens
        usdc.safeApprove(address(vault), amount);

        // 2. Capture share balance before
        uint256 sharesBefore = vault.shares(address(this));

        // 3. Deposit into Vault
        vault.deposit(amount, minShares);

        // 4. Calculate shares received
        uint256 sharesReceived = vault.shares(address(this)) - sharesBefore;
        
        emit DepositedToSavings(amount, sharesReceived);
    }

    /**
     * @notice Withdraws funds from the InvestorVault back to Checking (this contract).
     * @param shareAmount Amount of vault shares to burn.
     * @param minAssets Slippage protection (minimum USDC to receive).
     */
    function withdrawFromSavings(uint256 shareAmount, uint256 minAssets) external onlyOwner nonReentrant {
        require(vault.shares(address(this)) >= shareAmount, "CheckingAccount: Insufficient shares");

        uint256 balanceBefore = usdc.balanceOf(address(this));

        // Withdraw from Vault
        vault.withdraw(shareAmount, minAssets);

        uint256 assetsReceived = usdc.balanceOf(address(this)) - balanceBefore;
        
        emit WithdrawnFromSavings(shareAmount, assetsReceived);
    }

    /**
     * @notice View the savings balance (in Shares) of this account.
     */
    function getSavingsBalance() external view returns (uint256) {
        return vault.shares(address(this));
    }

    /**
     * @notice View the checking balance (in USDC) of this account.
     */
    function getCheckingBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    // -------------------------------------------------------------
    // Admin / Emergency
    // -------------------------------------------------------------

    /**
     * @notice Recover any ERC20 token sent to this contract by mistake.
     */
    function recoverToken(address _token, uint256 _amount) external onlyOwner nonReentrant {
        IERC20(_token).safeTransfer(owner, _amount);
        emit FundsRecovered(_token, _amount);
    }

    /**
     * @notice Recover native ETH sent to this contract by mistake.
     */
    function recoverETH() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to recover");
        
        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "ETH transfer failed");
        
        // Emitting address(0) to signify ETH
        emit FundsRecovered(address(0), balance);
    }
}

// =============================================================
//                       FACTORY
// =============================================================

/**
 * @title NeoBankFactory
 * @notice Factory to spawn personal CheckingAccount contracts.
 */
contract NeoBankFactory {
    // Registry of user => their personal contract address
    mapping(address => address) public getAccount;
    address[] public allAccounts;

    // Configuration
    address public immutable usdc;
    
    // Hardcoded Ecosystem Addresses provided by User
    address public constant INVESTOR_VAULT = 0x2761BF4292d9812FD1e757fD890a4cF4BF18A7dA;
    address public constant KERNEL = 0xC5ABA20edBF35544E5Adb9983b52831ec5d40FDD;

    event AccountCreated(address indexed user, address indexed accountAddress);

    constructor(address _usdc) {
        require(_usdc != address(0), "Invalid USDC address");
        usdc = _usdc;
    }

    /**
     * @notice Creates a new Checking Account for the caller.
     * @return accountAddress The address of the new CheckingAccount contract.
     */
    function createAccount() external returns (address accountAddress) {
        require(getAccount[msg.sender] == address(0), "Account already exists");

        // Deploy new CheckingAccount
        CheckingAccount newAccount = new CheckingAccount(
            msg.sender,     // Owner
            usdc,           // Currency
            INVESTOR_VAULT, // Yield Source
            KERNEL          // Core Logic
        );

        accountAddress = address(newAccount);
        
        // Update Registry
        getAccount[msg.sender] = accountAddress;
        allAccounts.push(accountAddress);

        emit AccountCreated(msg.sender, accountAddress);
    }

    /**
     * @notice Returns total number of accounts created.
     */
    function totalAccounts() external view returns (uint256) {
        return allAccounts.length;
    }
}
