# NeoBank Protocol 🏦  
_The Future of Personal Finance On-Chain_

NeoBank is a decentralized, self-custodial banking platform that bridges the gap between:

- Personal smart contract wallets  
- Institutional DeFi lending  
- Native Bitcoin cold storage  

It provides a unified interface for managing **Checking**, **Savings (Yield Vaults)**, and **Treasury** assets.

---

## 📚 Table of Contents

- [Overview](#-overview)
- [Key Features](#-key-features)
  - [Personal Banking](#-personal-banking)
  - [Investment & Lending (The Core)](#-investment--lending-the-core)
  - [Native Bitcoin Vault](#-native-bitcoin-vault)
  - [Interoperability](#-interoperability)
  - [Governance & Security](#-governance--security)
- [Architecture](#-architecture)
  - [Smart Contracts](#smart-contracts)
  - [Frontend Stack](#frontend-stack)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Configuration](#configuration)
- [User Guide](#-user-guide)
  - [1. Dashboard (My Account)](#1-dashboard-my-account)
  - [2. Bitcoin Tab](#2-bitcoin-tab)
  - [3. Ecosystem Tab](#3-ecosystem-tab)
  - [4. Admin Tab Owner-Only](#4-admin-tab-owner-only)
- [Security & Disclaimer](#%EF%B8%8F-security--disclaimer)
- [License](#-license)

---

## 🔍 Overview

NeoBank Protocol turns your on-chain wallet into a **personal bank**, with:

- Non-custodial **Checking Accounts** (smart contract wallets)
- Pooled **Investor Vaults** for yield and lending
- A **Kernel System** that routes capital to whitelisted borrowers (Solvers)
- Native **Bitcoin cold storage tracking** inside an EVM app

---

## 🌟 Key Features

### 👤 Personal Banking

- **Smart Checking Accounts**  
  Every user deploys their own `CheckingAccount` smart contract via a `NeoBankFactory`.

- **Self-Custody by Design**  
  You own the keys. You own the contract. No pooled custodial risk.

- **Daily Spending Limits**  
  Configure daily outflow caps to reduce damage in case of key compromise or malicious approvals.

- **Yield Integration**  
  One-click deposit of idle USDC into the `InvestorVault` to earn yield while funds are not in use.

---

### 💰 Investment & Lending (The Core)

- **Investor Vault**  
  Pooled capital vault that mints **shares** representing ownership in the pool.  
  - ERC20-style accounting  
  - Capital base for all lending activity

- **Kernel System – “The Brain”**  
  The Kernel manages protocol-level logic:
  - Enforces fee splits (DAO vs. Investors)
  - Routes capital to whitelisted **Solvers** (borrowers)
  - Orchestrates loan deployment and repayment

- **Atomic Utilization**  
  Capital only leaves the `InvestorVault` and moves to the `Kernel` when a loan is actually deployed.  
  - No idle capital parked in lending contracts  
  - Maximizes capital efficiency and utilization

---

### ₿ Native Bitcoin Vault

- **Cold Storage Tracking**  
  Monitor **native Bitcoin balances** on the Bitcoin mainnet directly from the EVM dashboard.

- **Live Mempool Data**  
  Uses public APIs (e.g., mempool.space) to fetch:
  - Current BTC balance
  - Live transaction history

- **Dynamic QR Codes**  
  Generate deposit addresses as QR codes for seamless cold-storage deposits.

---

### 🌉 Interoperability

- **Smart Bridging**  
  Integrated “Deposit” tab linking to cross-chain routers such as **Jumper.Exchange**:  
  - From Optimism, Base, Polygon → Arbitrum

- **Token Swaps**  
  Quick-link integration to DEXes (e.g., Uniswap) for:
  - USDC ↔ ETH  
  - USDC ↔ WBTC  

- **Fiat On-Ramp**  
  Direct links to providers like **MoonPay** for fiat → crypto purchases.

---

### 🛡️ Governance & Security

- **Timelocked Upgrades**  
  Critical system changes (e.g., upgrading the Kernel logic) are protected by a **48-hour timelock**.

- **Role-Based Access Control**  
  Admin roles control:
  - Whitelisting of investors  
  - Whitelisting of solvers (borrowers)

- **Reentrancy Protection**  
  All monetary functions are guarded using industry-standard **Reentrancy Guards**.

---

## 🏗 Architecture

The protocol is composed of:

- A **Frontend**: Single-Page Application (SPA)
- A set of **Smart Contracts** deployed on **Arbitrum**

### Smart Contracts

- **`NeoBankFactory`**  
  - Entry point to the system  
  - Deploys per-user `CheckingAccount` contracts  
  - Maintains a registry of users and their accounts

- **`CheckingAccount`**  
  - User’s personal smart contract wallet  
  - Holds USDC and potentially other supported assets  
  - Enforces daily spending limits  
  - Interfaces with the `InvestorVault` for savings/yield

- **`InvestorVault`**  
  - Holds pooled capital (e.g., USDC deposits)  
  - Issues **Shares** (ERC20-like) to represent ownership  
  - Enforces timelocks related to Kernel upgrades and configuration

- **`Kernel`**  
  - Core lending logic  
  - Whitelists **Solvers** (approved borrowers)  
  - Deploys loans and tracks principal & fees  
  - Distributes repayment fees according to predefined splits

---

### Frontend Stack

- **Core:**  
  - HTML5  
  - JavaScript (ES6+)

- **Blockchain:**  
  - `ethers.js` (v5.7.2)

- **Styling:**  
  - Tailwind CSS (via CDN)

- **Icons:**  
  - Lucide Icons

- **Data Sources:**  
  - `mempool.space` (or similar) APIs for Bitcoin data (balances, transactions)

---

## 🚀 Getting Started

### Prerequisites

You’ll need:

- A Web3-enabled wallet:  
  - e.g., **Rabby**, **MetaMask**

- Network access to:  
  - **Arbitrum One** (recommended target network)

- Some **USDC** for testing deposits and transfers.

---

### Installation

Clone the repository:

```bash
git clone https://github.com/your-username/neobank-protocol.git
cd neobank-protocol
