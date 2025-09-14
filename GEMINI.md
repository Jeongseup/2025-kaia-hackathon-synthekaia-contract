# GEMINI Project Brief: SynteKaia - Hybrid DeFi Strategy Vault

This document outlines the requirements for the SynteKaia project, organized for the Gemini AI assistant.

## 1. PM (Project Management) View

### 1.1. Project Overview
- **Project Name:** SynteKaia (also known as Hybrid DeFi Strategy Vault)
- **Core Concept:** A hybrid DeFi product that leverages a user's deposited KAIA assets to simultaneously generate stable interest income through **Liquid Staking** and hedge against market downturns while seeking additional returns via a **Perpetual Futures Short Position**.
- **Target Audience:**
    - KAIA holders seeking diversified yield strategies beyond simple staking.
    - DeFi investors interested in hedging against market volatility.

### 1.2. Core Features & Strategy
- **Automated Hybrid Investment Strategy (50/50 Split):** When a user deposits KAIA, the contract automatically splits the funds and executes two strategies:
    1.  **Liquid Staking (50%):** 50% of the KAIA is staked in the **stKAIA protocol**, generating continuous staking rewards. The asset is held as the liquid token `stKAIA`.
    2.  **PerpDEX Short Position (50%):** The remaining 50% of KAIA is swapped for **USDT** on a DEX (like KlaySwap). This USDT is then used as margin to open a **leveraged short position (e.g., 3x) on BTC** at a PerpDEX (like k-bit).

- **Extensibility & Maintenance:**
    - **Protocol Address Management:** The contract owner can update the addresses of integrated external protocols (stKAIA, PerpDEX, KlaySwap) via a dedicated function. This is a key feature for future-proofing, allowing for protocol upgrades or migration to better platforms.

### 1.3. System Architecture & User Flow
1.  **Deposit:** A user calls the `deposit()` function on the `HybridStrategyManager` contract, sending KAIA.
2.  **Automatic Execution:** The contract receives the KAIA, splits it 50/50, and executes both the staking and shorting strategies within a single transaction.
3.  **Asset Custody:** The resulting `stKAIA` tokens and the ownership of the PerpDEX position are securely held and managed by the `HybridStrategyManager` contract.

---

## 2. Developer (Contract) View

### 2.1. Tech Stack & Architecture
- **Language/Framework:** Solidity, Foundry
- **Core Architecture:**
    - **Modularity:** All interactions with external protocols are handled through interfaces (`IStKaia`, `IPerpDex`, `IKlaySwap`), ensuring a flexible and decoupled design.
    - **Security:** The main contract inherits from OpenZeppelin's battle-tested `Ownable` (for access control) and `ReentrancyGuard` (to prevent re-entrancy attacks).
    - **Testability:** The design uses Dependency Injection, allowing mock contracts to be easily substituted for real protocols during testing.

### 2.2. Source Code & File Structure

#### `src/interfaces/`
- **`IStKaia.sol`**:
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;
  interface IStKaia {
      function stakeFor(address recipient) external payable;
      function balanceOf(address account) external view returns (uint256);
  }
  ```
- **`IPerpDex.sol`**:
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;
  interface IPerpDex {
      enum TokenType { Btc, Klay, Wemix, Eth, Doge, Pepe, Sol, Xrp, Apt, Sui, Shib, Sei, Ada, Pol, Bnb, Dot, Ltc, Avax, Trump }
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
- **`IKlaySwap.sol`**:
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;
  interface IKlaySwap {
      function swapExactKLAYForTokens(
          uint amountOutMin,
          address[] calldata path,
          address to,
          uint deadline
      ) external payable returns (uint[] memory amounts);
  }
  ```

#### `src/`
- **`HybridStrategyManager.sol`**:
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;

  import "@openzeppelin/contracts/access/Ownable.sol";
  import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
  import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
  import "./interfaces/IStKaia.sol";
  import "./interfaces/IPerpDex.sol";
  import "./interfaces/IKlaySwap.sol";

  contract HybridStrategyManager is Ownable, ReentrancyGuard {
      IStKaia public stKaia;
      IPerpDex public perpDex;
      IKlaySwap public klaySwap;
      IERC20 public usdt;

      mapping(address => uint256) public userTotalDeposits;
      uint256 public totalKaiADeposited;

      event StrategyExecuted(address indexed user, uint256 totalDeposit, uint256 amountToStake, uint256 amountToShort);
      event ProtocolAddressesUpdated(address newStKaia, address newPerpDex, address newKlaySwap, address newUsdt);

      constructor(address _stKaiaAddress, address _perpDexAddress, address _klaySwapAddress, address _usdtAddress, address _initialOwner) Ownable(_initialOwner) {
          stKaia = IStKaia(_stKaiaAddress);
          perpDex = IPerpDex(_perpDexAddress);
          klaySwap = IKlaySwap(_klaySwapAddress);
          usdt = IERC20(_usdtAddress);
      }

      function deposit() external payable nonReentrant {
          uint256 totalDeposit = msg.value;
          require(totalDeposit > 0, "Deposit must be > 0");

          uint256 amountToStake = totalDeposit / 2;
          uint256 amountToSwap = totalDeposit - amountToStake;

          if (amountToStake > 0) {
              stKaia.stakeFor{value: amountToStake}(address(this));
          }

          if (amountToSwap > 0) {
              address[] memory path = new address[](2);
              path[0] = 0x0000000000000000000000000000000000000000;
              path[1] = address(usdt);

              uint[] memory amounts = klaySwap.swapExactKLAYForTokens{value: amountToSwap}(0, path, address(this), block.timestamp);
              uint256 usdtReceived = amounts[1];
              require(usdtReceived > 0, "Swap resulted in 0 USDT");

              usdt.approve(address(perpDex), usdtReceived);
              IPerpDex.OpenPositionData memory positionData = _buildShortPositionData(usdtReceived);
              perpDex.openPosition(positionData);
          }

          userTotalDeposits[msg.sender] += totalDeposit;
          totalKaiADeposited += totalDeposit;

          emit StrategyExecuted(msg.sender, totalDeposit, amountToStake, amountToSwap);
      }

      function updateProtocolAddresses(address _newStKaia, address _newPerpDex, address _newKlaySwap, address _newUsdt) external onlyOwner {
          require(_newStKaia != address(0) && _newPerpDex != address(0) && _newKlaySwap != address(0) && _newUsdt != address(0), "Address cannot be zero");
          stKaia = IStKaia(_newStKaia);
          perpDex = IPerpDex(_newPerpDex);
          klaySwap = IKlaySwap(_newKlaySwap);
          usdt = IERC20(_newUsdt);
          emit ProtocolAddressesUpdated(_newStKaia, _newPerpDex, _newKlaySwap, _newUsdt);
      }

      function _buildShortPositionData(uint256 _usdtMargin) internal pure returns (IPerpDex.OpenPositionData memory) {
          IPerpDex.OraclePrices memory prices; // Empty for testing
          return IPerpDex.OpenPositionData({
              tokenType: IPerpDex.TokenType.Btc,
              marginAmount: _usdtMargin,
              leverage: 3,
              long: false,
              trader: address(this),
              priceData: prices,
              tpPrice: 0,
              slPrice: 0,
              expectedPrice: 0,
              userSignedData: ""
          });
      }
  }
  ```

#### `script/`
- **`DeployHybridStrategyManager.s.sol`**:
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;

  import "forge-std/Script.sol";
  import "../src/HybridStrategyManager.sol";

  contract DeployHybridStrategyManager is Script {
      function run() external returns (HybridStrategyManager) {
          address ST_KAIA_ADDRESS = vm.envAddress("ST_KAIA_ADDRESS");
          address PERP_DEX_ADDRESS = vm.envAddress("PERP_DEX_ADDRESS");
          address KLAY_SWAP_ADDRESS = vm.envAddress("KLAY_SWAP_ADDRESS");
          address USDT_ADDRESS = vm.envAddress("USDT_ADDRESS");
          address INITIAL_OWNER = msg.sender;

          vm.startBroadcast();
          HybridStrategyManager manager = new HybridStrategyManager(
              ST_KAIA_ADDRESS,
              PERP_DEX_ADDRESS,
              KLAY_SWAP_ADDRESS,
              USDT_ADDRESS,
              INITIAL_OWNER
          );
          vm.stopBroadcast();
          
          console.log("HybridStrategyManager deployed at:", address(manager));
          return manager;
      }
  }
  ```

---

## 3. Test View

#### `src/test/` (Mock Contracts)
- **`MockStKaia.sol`**:
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;
  import "../interfaces/IStKaia.sol";
  contract MockStKaia is IStKaia {
      mapping(address => uint256) private _balances;
      function stakeFor(address recipient) external payable override {
          _balances[recipient] += msg.value;
      }
      function balanceOf(address account) external view override returns (uint256) {
          return _balances[account];
      }
  }
  ```
- **`MockPerpDex.sol`**:
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;
  import "../interfaces/IPerpDex.sol";
  import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
  contract MockPerpDex is IPerpDex {
      IERC20 public usdt;
      OpenPositionData public lastOpenPositionData;
      constructor(address _usdtAddress) {
          usdt = IERC20(_usdtAddress);
      }
      function openPosition(OpenPositionData calldata o) external payable override {
          lastOpenPositionData = o;
          if (o.marginAmount > 0) {
              usdt.transferFrom(msg.sender, address(this), o.marginAmount);
          }
      }
  }
  ```
- **`MockKlaySwap.sol`**:
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;
  import "../interfaces/IKlaySwap.sol";
  import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
  interface IMintable { function mint(address to, uint256 amount) external; }
  contract MockKlaySwap is IKlaySwap {
      IERC20 public usdt;
      uint256 public constant KAIA_TO_USDT_RATE = 3 * 1e5; // 0.3 * 10^6
      constructor(address _usdtAddress) {
          usdt = IERC20(_usdtAddress);
      }
      function swapExactKLAYForTokens(uint amountOutMin, address[] calldata, address to, uint) external payable override returns (uint[] memory amounts) {
          uint256 kaiaAmount = msg.value;
          uint256 usdtAmount = (kaiaAmount * KAIA_TO_USDT_RATE) / 1 ether;
          require(usdtAmount >= amountOutMin, "MockKlaySwap: Insufficient output amount");
          IMintable(address(usdt)).mint(address(this), usdtAmount);
          usdt.transfer(to, usdtAmount);
          amounts = new uint[](2);
          amounts[0] = kaiaAmount;
          amounts[1] = usdtAmount;
          return amounts;
      }
  }
  ```

#### `test/`
- **`HybridStrategyManager.t.sol`**:
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;

  import "forge-std/Test.sol";
  import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
  import "../src/HybridStrategyManager.sol";
  import "../src/test/MockStKaia.sol";
  import "../src/test/MockPerpDex.sol";
  import "../src/test/MockKlaySwap.sol";

  contract MockUSDT is ERC20 {
      constructor() ERC20("Mock USDT", "mUSDT") {}
      function mint(address to, uint256 amount) public { _mint(to, amount); }
  }

  contract HybridStrategyManagerTest is Test {
      HybridStrategyManager public manager;
      MockStKaia public mockStKaia;
      MockPerpDex public mockPerpDex;
      MockKlaySwap public mockKlaySwap;
      MockUSDT public mockUsdt;
      address public owner = makeAddr("owner");
      address public user = makeAddr("user");

      function setUp() public {
          mockStKaia = new MockStKaia();
          mockUsdt = new MockUSDT();
          mockPerpDex = new MockPerpDex(address(mockUsdt));
          mockKlaySwap = new MockKlaySwap(address(mockUsdt));
          manager = new HybridStrategyManager(address(mockStKaia), address(mockPerpDex), address(mockKlaySwap), address(mockUsdt), owner);
      }

      function test_deposit_ExecutesBothStrategiesCorrectly() public {
          uint256 totalDeposit = 100 ether;
          vm.deal(user, totalDeposit);
          uint256 expectedStakeAmount = totalDeposit / 2;
          uint256 expectedSwapAmount = totalDeposit - expectedStakeAmount;
          uint256 expectedUsdtReceived = (expectedSwapAmount * mockKlaySwap.KAIA_TO_USDT_RATE()) / 1 ether;

          vm.prank(user);
          manager.deposit{value: totalDeposit}();

          assertEq(manager.totalKaiADeposited(), totalDeposit);
          assertEq(manager.userTotalDeposits(user), totalDeposit);
          assertEq(mockStKaia.balanceOf(address(manager)), expectedStakeAmount);
          assertEq(mockUsdt.balanceOf(address(mockPerpDex)), expectedUsdtReceived);
      }

      function test_UpdateProtocolAddresses_Success() public {
          address newStKaia = makeAddr("newStKaia");
          address newPerpDex = makeAddr("newPerpDex");
          address newKlaySwap = makeAddr("newKlaySwap");
          address newUsdt = makeAddr("newUsdt");

          vm.prank(owner);
          manager.updateProtocolAddresses(newStKaia, newPerpDex, newKlaySwap, newUsdt);

          assertEq(address(manager.stKaia()), newStKaia);
          assertEq(address(manager.perpDex()), newPerpDex);
          assertEq(address(manager.klaySwap()), newKlaySwap);
          assertEq(address(manager.usdt()), newUsdt);
      }
  }
  ```

---

## 4. Reference View
- **stKAIA Contract:** [https://github.com/stakely-protocol/stakely-core](https://github.com/stakely-protocol/stakely-core)
- **perpDEX Contract:** [https://github.com/devKBit/k-bit](https://github.com/devKBit/k-bit)

---

## 5. Project Summary for Gemini Assistant

**Objective:** Create the SynteKaia Foundry project based on the provided specifications.

**Action Plan:**
1.  **File Creation:** Create the complete file structure and populate each file with the source code provided in this document.
    - Interfaces: `IStKaia.sol`, `IPerpDex.sol`, `IKlaySwap.sol`
    - Main Contract: `HybridStrategyManager.sol`
    - Mock Contracts: `MockStKaia.sol`, `MockPerpDex.sol`, `MockKlaySwap.sol`
    - Test: `HybridStrategyManager.t.sol`
    - Script: `DeployHybridStrategyManager.s.sol`
2.  **Configuration:** Ensure `foundry.toml` is correctly configured with the remapping: `remappings = ['@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/']`.
3.  **Build & Test:**
    - Run `forge build` to compile the contracts.
    - Run `forge test` to execute the tests and verify the implementation.
4.  **Troubleshoot:** If compilation or tests fail, debug the issue. The most likely cause is an incorrect import path or remapping configuration.
