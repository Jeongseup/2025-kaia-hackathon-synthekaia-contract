# GEMINI Project Brief: SyntheKaia - Delta Neutral Vault Strategy

This document outlines the requirements for the SyntheKaia project, organized for the Gemini AI assistant.

## 1. PM (Project Management) View

### 1.1. Project Overview

- **Project Name:** SyntheKaia (Stkaia Delta Neutral Vault)
- **Core Concept:** A sophisticated DeFi vault that implements a delta-neutral strategy by accepting USDT deposits and simultaneously executing two complementary strategies: **Liquid Staking** (converting 50% USDT to stKAIA) and **Perpetual Futures Short Position** (using remaining 50% USDT as margin for leveraged short positions on K-bit PerpDEX).
- **Target Audience:**
  - USDT holders seeking delta-neutral yield strategies on the Kaia network.
  - DeFi investors interested in market-neutral returns with reduced volatility exposure.

### 1.2. Core Features & Strategy

- **Automated Delta Neutral Strategy (50/50 Split):** When a user deposits USDT, the vault automatically splits the funds and executes two strategies:

  1.  **Liquid Staking (50%):** 50% of the USDT is swapped to **stKAIA** via Uniswap V3, generating continuous staking rewards through the liquid staking protocol.
  2.  **PerpDEX Short Position (50%):** The remaining 50% of USDT is used as margin to open a **leveraged short position (2x) on KAIA** at K-bit PerpDEX, providing downside protection and potential profit from market declines.

- **ERC4626 Standard Compliance:**
  - **Vault Shares:** Users receive vault share tokens (sdnVS) representing their proportional ownership of the vault's assets.
  - **Upgradeable Architecture:** Built using OpenZeppelin's upgradeable contracts for future enhancements and bug fixes.
  - **Security Features:** Implements pausable functionality, reentrancy protection, and owner access controls.

### 1.3. System Architecture & User Flow

1.  **Deposit:** A user calls the `deposit()` function on the `StkaiaDeltaNeutralVault` contract, sending USDT.
2.  **Automatic Execution:** The vault receives the USDT, splits it 50/50, and executes both the staking (via Uniswap V3 swap) and shorting strategies within a single transaction.
3.  **Asset Custody:** The resulting `stKAIA` tokens and the ownership of the PerpDEX position are securely held and managed by the vault contract.
4.  **Share Tokens:** Users receive ERC4626-compliant vault shares representing their proportional claim on the vault's total assets.

---

## 2. Developer (Contract) View

### 2.1. Tech Stack & Architecture

- **Language/Framework:** Solidity ^0.8.20, Foundry
- **Core Architecture:**
  - **ERC4626 Standard:** Implements the ERC4626 vault standard for tokenized vaults, providing standardized deposit/withdraw functionality.
  - **Upgradeable Contracts:** Built using OpenZeppelin's upgradeable contracts (`Initializable`, `ERC4626Upgradeable`, `OwnableUpgradeable`, `PausableUpgradeable`, `ReentrancyGuardUpgradeable`).
  - **Modularity:** All interactions with external protocols are handled through interfaces (`IUniswapV3Router`, `IPerpDex`, `IUSDT`), ensuring a flexible and decoupled design.
  - **Security:** Implements comprehensive security measures including reentrancy protection, pausable functionality, and owner access controls.

### 2.2. Source Code & File Structure

#### `src/interfaces/`

- **`IUniswapV3Router.sol`**:

  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;

  interface IUniswapV3Router {
      struct ExactInputSingleParams {
          address tokenIn;
          address tokenOut;
          uint24 fee;
          address recipient;
          uint256 amountIn;
          uint256 amountOutMinimum;
          uint160 sqrtPriceLimitX96;
      }

      function exactInputSingle(
          ExactInputSingleParams calldata params
      ) external payable returns (uint256 amountOut);
  }
  ```

- **`IPerpDex.sol`**:

  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;

  interface IPerpDex {
      enum TokenType {
          Btc, Klay, Wemix, Eth, Doge, Pepe, Sol, Xrp, Apt, Sui, Shib, Sei, Ada, Pol, Bnb, Dot, Ltc, Avax, Trump
      }

      enum OracleType { BisonAI, Pyth }

      struct OraclePrices {
          OracleType oracleType;
          bytes32[] feedHashes;
          int256[] answers;
          uint256[] timestamps;
          bytes[] proofs;
      }

      struct OpenPositionData {
          TokenType tokenType;
          uint256 marginAmount;
          uint256 leverage;
          bool long;
          address trader;
          OraclePrices priceData;
          uint256 tpPrice;
          uint256 slPrice;
          uint256 expectedPrice;
          bytes userSignedData;
      }

      function openPosition(OpenPositionData calldata o) external payable;
  }
  ```

- **`IUSDT.sol`**:

  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;

  interface IUSDT {
      function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
      function approve(address spender, uint256 amount) external returns (bool);
      function balanceOf(address account) external view returns (uint256);
  }
  ```

#### `src/`

- **`StkaiaDeltaNeutralVault.sol`** (Core Contract):

  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;

  import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
  import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
  import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
  import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
  import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
  import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
  import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

  import {IUniswapV3Router} from "./interfaces/IUniswapV3Router.sol";
  import {IPerpDex} from "./interfaces/IPerpDex.sol";

  contract StkaiaDeltaNeutralVault is
      Initializable,
      ERC4626Upgradeable,
      OwnableUpgradeable,
      PausableUpgradeable,
      ReentrancyGuardUpgradeable
  {
      using SafeERC20 for IERC20;

      // External contract interfaces
      IUniswapV3Router public uniswapRouter;
      IPerpDex public perpDex;
      IERC20 public stKAIA;

      // Strategy configuration variables
      uint24 public swapFee; // Uniswap V3 pool fee (e.g., 3000 for 0.3%)
      uint256 public leverage; // Short position leverage (e.g., 2 * 1e18 for 2x)
      IPerpDex.TokenType public perpDexTokenType; // Token type to trade on K-bit DEX

      // Events
      event StrategyExecuted(
          uint256 totalUsdtAmount,
          uint256 amountSwapped,
          uint256 amountShorted,
          uint256 stKAIAAmountReceived
      );

      constructor() {
          _disableInitializers();
      }

      function initialize(
          address _asset, // USDT
          address _stKAIA,
          address _uniswapRouter,
          address _perpDex,
          address _initialOwner
      ) public initializer {
          __ERC4626_init(IERC20(_asset));
          __ERC20_init("Stkaia Delta Neutral Vault Share", "sdnVS");
          __Ownable_init(_initialOwner);
          __Pausable_init();
          __ReentrancyGuard_init();

          stKAIA = IERC20(_stKAIA);
          uniswapRouter = IUniswapV3Router(_uniswapRouter);
          perpDex = IPerpDex(_perpDex);

          swapFee = 3000;
          leverage = 2 * 1e18;
          perpDexTokenType = IPerpDex.TokenType.Klay;
      }

      function deposit(
          uint256 assets,
          address receiver
      ) public override nonReentrant whenNotPaused returns (uint256 shares) {
          require(assets > 0, "Vault: amount must be > 0");

          shares = super.deposit(assets, receiver);

          IPerpDex.OraclePrices memory emptyOraclePrices;
          _executeStrategy(assets, emptyOraclePrices);
      }

      function _executeStrategy(
          uint256 _usdtAmount,
          IPerpDex.OraclePrices memory _oraclePrices
      ) internal {
          require(_usdtAmount > 0, "Vault: amount must be > 0");

          uint256 amountToSwap = _usdtAmount / 2;
          uint256 amountToShort = _usdtAmount - amountToSwap;

          IERC20 usdt = IERC20(asset());

          // Swap USDT to stKAIA via Uniswap V3
          usdt.approve(address(uniswapRouter), 0);
          usdt.approve(address(uniswapRouter), amountToSwap);

          IUniswapV3Router.ExactInputSingleParams memory params = IUniswapV3Router
              .ExactInputSingleParams({
                  tokenIn: address(usdt),
                  tokenOut: address(stKAIA),
                  fee: swapFee,
                  recipient: address(this),
                  amountIn: amountToSwap,
                  amountOutMinimum: 0,
                  sqrtPriceLimitX96: 0
              });
          uint256 stKAIAAmountReceived = uniswapRouter.exactInputSingle(params);

          // Open short position on K-bit PerpDEX
          if (amountToShort > 0) {
              usdt.approve(address(perpDex), 0);
              usdt.approve(address(perpDex), amountToShort);

              IPerpDex.OpenPositionData memory posData = IPerpDex
                  .OpenPositionData({
                      tokenType: perpDexTokenType,
                      marginAmount: amountToShort,
                      leverage: leverage,
                      long: false, // Short position
                      trader: address(this),
                      priceData: _oraclePrices,
                      tpPrice: 0,
                      slPrice: 0,
                      expectedPrice: 0,
                      userSignedData: ""
                  });
              perpDex.openPosition(posData);
          }

          emit StrategyExecuted(
              _usdtAmount,
              amountToSwap,
              amountToShort,
              stKAIAAmountReceived
          );
      }

      function totalAssets() public view override returns (uint256) {
          // TODO: Include stKAIA balance value and short position PnL in total asset calculation
          return IERC20(asset()).balanceOf(address(this));
      }
  }
  ```

### 2.3. Key Contract Features

#### Core Functionality

- **ERC4626 Vault Standard:** Implements the industry-standard vault interface for tokenized assets
- **Delta Neutral Strategy:** Automatically executes 50/50 split between stKAIA liquid staking and KAIA short positions
- **Upgradeable Architecture:** Uses OpenZeppelin's upgradeable contracts for future enhancements
- **Security Measures:** Includes pausable functionality, reentrancy protection, and owner access controls

#### Strategy Execution Flow

1. **Deposit Processing:** Users deposit USDT and receive vault shares (sdnVS tokens)
2. **Strategy Split:** Deposited USDT is automatically split 50/50
3. **Liquid Staking:** 50% USDT → stKAIA via Uniswap V3 swap
4. **Short Position:** 50% USDT → leveraged short position on KAIA via K-bit PerpDEX
5. **Asset Management:** Vault holds stKAIA tokens and manages PerpDEX positions

#### Configuration Parameters

- **Swap Fee:** 3000 (0.3% Uniswap V3 pool fee)
- **Leverage:** 2x for short positions
- **Token Type:** KAIA for PerpDEX trading
- **Oracle Integration:** Supports BisonAI and Pyth oracle types

---

## 3. Implementation Analysis

### 3.1. Contract Architecture Analysis

#### Core Contract: `StkaiaDeltaNeutralVault.sol`

The main vault contract implements a sophisticated delta-neutral strategy with the following key characteristics:

**Inheritance Chain:**

- `Initializable` - Enables upgradeable contract pattern
- `ERC4626Upgradeable` - Standard vault interface for tokenized assets
- `OwnableUpgradeable` - Owner access control
- `PausableUpgradeable` - Emergency pause functionality
- `ReentrancyGuardUpgradeable` - Protection against reentrancy attacks

**Key State Variables:**

- `uniswapRouter` - Uniswap V3 router for USDT → stKAIA swaps
- `perpDex` - K-bit PerpDEX for short position management
- `stKAIA` - Liquid staking token interface
- `swapFee` - Uniswap V3 pool fee (3000 = 0.3%)
- `leverage` - Short position leverage (2x)
- `perpDexTokenType` - Token type for PerpDEX (KAIA)

### 3.2. Strategy Implementation Details

#### Deposit Flow (`deposit` function)

1. **Validation:** Ensures deposit amount > 0
2. **ERC4626 Processing:** Calls parent `deposit` to handle share calculation and token transfers
3. **Strategy Execution:** Calls `_executeStrategy` with deposited USDT amount

#### Strategy Execution (`_executeStrategy` function)

1. **Amount Calculation:** Splits USDT 50/50 for swap and short position
2. **USDT → stKAIA Swap:**
   - Approves Uniswap V3 router
   - Executes exact input single swap
   - Receives stKAIA tokens
3. **Short Position Opening:**
   - Approves PerpDEX contract
   - Creates `OpenPositionData` struct
   - Opens leveraged short position on KAIA

### 3.3. Security Considerations

#### Implemented Security Measures

- **Reentrancy Protection:** `nonReentrant` modifier on deposit function
- **Pausable Functionality:** `whenNotPaused` modifier for emergency stops
- **Owner Controls:** Only owner can perform administrative functions
- **SafeERC20:** Uses OpenZeppelin's SafeERC20 for token operations

#### Areas Requiring Attention

- **Oracle Price Data:** Currently uses empty oracle prices (marked as TODO)
- **Slippage Protection:** `amountOutMinimum` set to 0 (marked as TODO)
- **Total Assets Calculation:** Only returns USDT balance, needs stKAIA and position PnL integration

### 3.4. Integration Points

#### External Protocol Dependencies

1. **Uniswap V3:** For USDT → stKAIA swaps
2. **K-bit PerpDEX:** For leveraged short positions
3. **stKAIA Protocol:** For liquid staking rewards

#### Interface Requirements

- `IUniswapV3Router` - Uniswap V3 swap functionality
- `IPerpDex` - PerpDEX position management
- `IUSDT` - USDT token operations

---

## 4. Development Status & Next Steps

### 4.1. Current Implementation Status

#### Completed Features

- ✅ **Core Vault Contract:** `StkaiaDeltaNeutralVault.sol` with ERC4626 standard
- ✅ **Interface Definitions:** All required interfaces for external protocol integration
- ✅ **Strategy Logic:** 50/50 split between stKAIA liquid staking and KAIA short positions
- ✅ **Security Framework:** Reentrancy protection, pausable functionality, owner controls
- ✅ **Upgradeable Architecture:** OpenZeppelin upgradeable contracts implementation

#### Pending Implementation (TODOs in Code)

- ⚠️ **Oracle Integration:** Real oracle price data for PerpDEX positions
- ⚠️ **Slippage Protection:** Proper `amountOutMinimum` calculation for swaps
- ⚠️ **Total Assets Calculation:** Include stKAIA balance and position PnL in vault valuation
- ⚠️ **Withdrawal Logic:** ERC4626 withdraw/redeem functions with strategy liquidation
- ⚠️ **Position Management:** Close/modify PerpDEX positions functionality

### 4.2. External Protocol Integration

#### Required Protocol Addresses

- **USDT Token:** Kaia network USDT contract address
- **stKAIA Token:** Liquid staking token contract address
- **Uniswap V3 Router:** Compatible DEX router for USDT → stKAIA swaps
- **K-bit PerpDEX:** Perpetual futures DEX for short positions

#### Integration Requirements

- **Oracle Data:** BisonAI or Pyth oracle integration for price feeds
- **Liquidity Pools:** Sufficient USDT/stKAIA liquidity on Uniswap V3
- **PerpDEX Setup:** Proper margin requirements and position limits

### 4.3. Testing & Deployment Considerations

#### Testing Requirements

- **Mock Contracts:** Create mock implementations for external protocols
- **Integration Tests:** Test complete deposit → strategy execution flow
- **Edge Cases:** Test with minimal amounts, oracle failures, protocol downtime
- **Security Tests:** Reentrancy, access control, and pause functionality

#### Deployment Checklist

- **Proxy Pattern:** Deploy implementation contract with proxy for upgrades
- **Initialization:** Proper contract initialization with all required parameters
- **Verification:** Contract verification on block explorer
- **Monitoring:** Set up monitoring for strategy execution and vault health

---

## 5. Technical Specifications Summary

**Core Contract:** `StkaiaDeltaNeutralVault.sol`

- **Standard:** ERC4626 Vault
- **Architecture:** Upgradeable with OpenZeppelin
- **Strategy:** Delta-neutral (50% stKAIA liquid staking + 50% KAIA short)
- **Security:** Reentrancy protection, pausable, owner controls
- **Integration:** Uniswap V3, K-bit PerpDEX, stKAIA protocol

**Key Features:**

- Automated strategy execution on deposit
- ERC4626-compliant vault shares (sdnVS)
- Upgradeable contract architecture
- Comprehensive security measures
- Modular interface-based design

**Development Status:** Core implementation complete, pending oracle integration and advanced features
