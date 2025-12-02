NeoBank Protocol 🏦

The Future of Personal Finance on-chain.

NeoBank is a decentralized, self-custodial banking platform that bridges the gap between personal smart contract wallets, institutional DeFi lending, and native Bitcoin cold storage. It provides a unified interface for managing Checking, Savings (Yield Vaults), and Treasury assets.

🌟 Key Features

👤 Personal Banking

Smart Checking Accounts: Every user deploys their own CheckingAccount smart contract via a Factory.

Self-Custody: You own the keys. You own the contract.

Daily Spending Limits: Set security caps on daily outflows to protect against key compromise.

Yield Integration: One-click deposits into the InvestorVault to earn yield on idle USDC.

💰 Investment & Lending (The Core)

Investor Vault: A pooled investment vehicle that mints shares representing ownership.

Kernel System: The "Brain" of the protocol. It manages liquidity, enforces fee splits (DAO vs Investors), and routes capital to whitelisted Solvers.

Atomic Utilization: Capital is pulled from the Vault to the Kernel only when a loan is deployed, maximizing efficiency.

₿ Native Bitcoin Vault

Cold Storage Tracking: Monitor native Bitcoin assets on the Bitcoin Mainnet directly from the EVM dashboard.

Live Mempool Data: Fetches real-time balances and transaction history using public APIs.

Dynamic QR Codes: Generate deposit addresses for your cold storage instantly.

🌉 Interoperability

Smart Bridging: Integrated "Deposit" tab linking to Jumper.Exchange for cross-chain transfers (Optimism, Base, Polygon -> Arbitrum).

Token Swaps: Quick link integration for swapping USDC/ETH/WBTC via Uniswap.

Fiat On-Ramp: Direct links to MoonPay for fiat-to-crypto purchases.

🛡️ Governance & Security

Timelocked Upgrades: Critical system changes (like upgrading the Kernel) require a 48-hour timelock.

Role-Based Access: Admin controls for whitelisting investors and solvers.

Reentrancy Protection: All monetary functions are guarded against reentrancy attacks.

🏗 Architecture

The system consists of a Frontend (Single-Page Application) and a set of Smart Contracts on Arbitrum.

Smart Contracts

NeoBankFactory: The entry point. Deploys personal CheckingAccount contracts and maintains a registry of users.

CheckingAccount: The user's personal wallet. Holds USDC, manages daily limits, and interacts with the Vault.

InvestorVault: Holds pooled capital. Issues Shares (ERC20-like accounting) to depositors. Enforces timelocks on Kernel upgrades.

Kernel: Manages lending logic. Whitelists "Solvers" (borrowers), issues loans, and distributes repayment fees.

Frontend Stack

Core: HTML5, JavaScript (ES6+)

Blockchain: Ethers.js (v5.7.2)

Styling: Tailwind CSS (CDN)

Icons: Lucide Icons

Data: Mempool.space API (for Bitcoin data)

🚀 Getting Started

Prerequisites

A Web3 Wallet (e.g., Rabby, MetaMask).

An EVM-compatible network (Arbitrum One recommended).

USDC tokens for testing.

Installation

Clone the repository:

git clone [https://github.com/your-username/neobank-protocol.git](https://github.com/your-username/neobank-protocol.git)


Open the Interface:
Simply open index.html in any modern web browser. No build process (npm install / npm start) is required for the frontend as it uses CDN libraries for portability.

Configuration

To point the frontend to your own deployed contracts, edit the configuration block at the bottom of index.html:

// --- CONFIGURATION ---
const FACTORY_ADDRESS = "0xYOUR_FACTORY_ADDRESS_HERE"; 
const RELAY_API_KEY = "YOUR_RELAY_API_KEY"; // Optional: For future Relay integration


📖 User Guide

1. Dashboard (My Account)

Connect Wallet: Connect your EOA (Externally Owned Account).

Create Account: If you are new, click "Deploy Smart Account" to create your on-chain Checking contract.

Top Up: Send USDC from your EOA to your Checking Account.

Transfer: Send payments to other addresses (subject to Daily Limits).

Savings: Deposit USDC into the Vault to earn yield. You receive Shares in return.

2. Bitcoin Tab

Setup: Enter your public Bitcoin Address (e.g., bc1q... or 3...) to track your cold storage.

Deposit: Click "Deposit" to see your QR code. Send native BTC from any exchange or wallet.

History: View live incoming/outgoing BTC transactions.

3. Ecosystem Tab

View global protocol stats: Total Value Locked (TVL), Share Price, and Capital Utilization.

Solver Inspector: Check if an address is a whitelisted borrower and view their active principal.

4. Admin Tab (Owner Only)

Lending Operations:

Issue Loan: Deploy capital from the Vault -> Kernel -> Solver.

Governance:

Propose Kernel: Start the 48h timer to upgrade the system logic.

Execute Upgrade: Finalize the upgrade after the timer expires.

Management:

Manage Solvers: Whitelist addresses allowed to borrow funds.

Manage Investors: Whitelist user Checking Accounts allowed to deposit.

⚠️ Disclaimer

This software is provided "as is" without warranty of any kind. The smart contracts utilize advanced patterns such as Timelocks and Reentrancy Guards, but have not been audited by a third party. Use at your own risk. Ensure you verify all addresses and limits before deploying substantial capital.
