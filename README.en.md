# SynteKaia: Delta Neutral Vault Strategy

SynteKaia is a sophisticated decentralized finance (DeFi) vault built on the Kaia network that implements a delta-neutral investment strategy. It accepts USDT deposits and automatically executes a dual-strategy approach to generate yield while maintaining market neutrality through strategic hedging.

## Core Strategy

When a user deposits USDT into the `StkaiaDeltaNeutralVault` contract, the funds are automatically allocated to two complementary strategies within a single transaction:

1.  **Liquid Staking (50%)**: Half of the USDT is swapped to **stKAIA** tokens via Uniswap V3. This generates continuous, stable staking rewards through the liquid staking protocol while maintaining exposure to KAIA's staking yield.
2.  **Perpetual Short Position (50%)**: The remaining half is used as margin to open a leveraged short position (2x) on **KAIA** at K-bit PerpDEX. This serves as a hedge against potential KAIA price declines, creating a delta-neutral exposure.

## Delta Neutral Benefits

This strategy aims to:
- **Reduce Volatility**: The short position hedges against KAIA price movements
- **Generate Yield**: Earn staking rewards from the stKAIA position
- **Market Neutral**: Profit from both upward and downward price movements
- **Capital Efficiency**: Leverage the short position to maximize hedging effectiveness

## Tech Stack

- **Smart Contracts**: Solidity ^0.8.20
- **Development Framework**: Foundry
- **Standards**: ERC4626 Vault Standard
- **Security**: OpenZeppelin Upgradeable Contracts
- **Dependencies**: Uniswap V3, K-bit PerpDEX, stKAIA Protocol

## Architecture

### ERC4626 Vault Implementation
The vault implements the ERC4626 standard, providing:
- **Standardized Interface**: Compatible with existing DeFi infrastructure
- **Vault Shares**: Users receive `sdnVS` tokens representing their proportional ownership
- **Automated Strategy**: Strategy execution triggered automatically on deposit

### Upgradeable Contract Design
Built using OpenZeppelin's upgradeable contracts:
- **Future-Proof**: Allows for bug fixes and feature enhancements
- **Security**: Implements comprehensive security measures
- **Access Control**: Owner-managed administrative functions

## Project Structure

The project is organized with a focus on modularity, security, and testability:

```
.
├── src/
│   ├── StkaiaDeltaNeutralVault.sol  # Core vault contract (ERC4626)
│   └── interfaces/                  # External protocol interfaces
│       ├── IUniswapV3Router.sol    # Uniswap V3 swap interface
│       ├── IPerpDex.sol            # K-bit PerpDEX interface
│       └── IUSDT.sol               # USDT token interface
├── lib/                             # Dependencies (OpenZeppelin, Forge-std)
├── test/                            # Test files (to be implemented)
├── script/                          # Deployment scripts (to be implemented)
├── Makefile                         # Build and deployment shortcuts
└── foundry.toml                     # Foundry configuration
```

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) must be installed.

### Installation

1.  Clone the repository:

    ```bash
    git clone <your-repo-url>
    cd 2025-hackathon-kaia-syntekaia-contract
    ```

2.  Install dependencies:
    ```bash
    forge install
    ```

### Configuration

Before you can deploy the contract, you must configure your environment. Create a `.env` file in the project root by copying the example below.

```dotenv
# .env
# RPC URL for the target Kaia network (e.g., Baobab Testnet or Kaia Mainnet)
KAIA_RPC_URL="https://your-kaia-rpc-provider.com"

# The private key of the wallet you will use to deploy.
# WARNING: Never commit this file to a public repository.
PRIVATE_KEY="0xyour_wallet_private_key"

# Protocol addresses on the target network
USDT_ADDRESS="0x..."                    # USDT token contract address
ST_KAIA_ADDRESS="0x..."                # stKAIA liquid staking token address
UNISWAP_V3_ROUTER_ADDRESS="0x..."     # Uniswap V3 router address
PERP_DEX_ADDRESS="0x..."              # K-bit PerpDEX contract address
```

**Important**: You must replace the placeholder values with the actual addresses of the protocols on your target network and your personal wallet information.

### Key Configuration Parameters

The vault contract uses the following default parameters:
- **Swap Fee**: 3000 (0.3% Uniswap V3 pool fee)
- **Leverage**: 2x for short positions
- **Token Type**: KAIA for PerpDEX trading
- **Oracle Type**: Supports BisonAI and Pyth oracles

## Usage (Makefile Commands)

This project uses a `Makefile` to provide simple shortcuts for the most common tasks.

- **`make build`**
  Compile all smart contracts in the project.

- **`make test`**
  Run the Foundry test suite. This uses mock contracts to verify the core logic in a local environment.

- **`make fmt`**
  Format the Solidity code using `forge fmt`.

- **`make clean`**
  Remove the build artifacts (`out/`) and cache directories.

- **`make deploy`**
  Deploy the `StkaiaDeltaNeutralVault` contract to the network specified in your `.env` file. This command will fail with an error if `KAIA_RPC_URL` or `PRIVATE_KEY` are not set.

## How It Works

### Deposit Process
1. **User Deposits USDT**: Users call the `deposit()` function with USDT tokens
2. **Vault Shares Issued**: Users receive `sdnVS` tokens representing their vault share
3. **Strategy Execution**: The vault automatically executes the delta-neutral strategy:
   - 50% USDT → stKAIA via Uniswap V3 swap
   - 50% USDT → leveraged short position on KAIA via K-bit PerpDEX

### Strategy Benefits
- **Market Neutral**: The short position hedges against KAIA price movements
- **Yield Generation**: Earn staking rewards from stKAIA holdings
- **Automated Management**: No manual intervention required
- **ERC4626 Compatible**: Works with existing DeFi infrastructure

### Security Features
- **Reentrancy Protection**: Prevents reentrancy attacks
- **Pausable Functionality**: Emergency stop capability
- **Owner Controls**: Administrative functions restricted to owner
- **Upgradeable**: Future enhancements possible through proxy pattern

## Testing

To run the full test suite and ensure the contract logic is sound:

```bash
make test
```

**Note**: Test files are currently being developed. The test suite will include:
- Mock contracts for external protocols
- Integration tests for the complete deposit flow
- Security tests for reentrancy and access controls
- Edge case testing for minimal amounts and protocol failures

## Deployment

### Prerequisites
1. Ensure your `.env` file is correctly configured with your private key, RPC URL, and the correct protocol addresses for your target network.
2. Verify that all required external protocols are deployed and accessible on your target network.

### Deploy Steps
1. Run the deployment command:

    ```bash
    make deploy
    ```

2. If successful, the address of your newly deployed `StkaiaDeltaNeutralVault` contract will be printed to the console.

3. **Important**: Since this is an upgradeable contract, you'll need to deploy both the implementation contract and a proxy contract. The proxy address is what you'll use to interact with the vault.

4. You can now use the contract address and ABI (found in `out/StkaiaDeltaNeutralVault.sol/StkaiaDeltaNeutralVault.json`) to interact with it from a frontend dApp.

### Post-Deployment
- **Initialize the Contract**: Call the `initialize()` function with the required parameters
- **Verify Deployment**: Check that the contract is properly initialized and accessible
- **Monitor**: Set up monitoring for strategy execution and vault health

## Development Status

### ✅ Completed Features
- Core vault contract with ERC4626 standard
- Delta-neutral strategy implementation
- Security framework with comprehensive protections
- Upgradeable contract architecture
- Interface definitions for external protocols

### ⚠️ In Development
- Oracle integration for PerpDEX positions
- Slippage protection for swaps
- Complete total assets calculation
- Withdrawal and redemption logic
- Comprehensive test suite

### 🔄 Future Enhancements
- Advanced position management
- Dynamic leverage adjustment
- Multi-token support
- Yield optimization strategies

## Risk Considerations

**Important**: This is experimental software. Users should be aware of the following risks:

- **Smart Contract Risk**: Bugs in the contract code could lead to loss of funds
- **Protocol Risk**: Dependency on external protocols (Uniswap V3, K-bit PerpDEX, stKAIA)
- **Market Risk**: Delta-neutral strategies may not perform as expected in all market conditions
- **Liquidity Risk**: Insufficient liquidity in external protocols could impact strategy execution
- **Oracle Risk**: Price feed failures could affect PerpDEX position management

## License

This project is licensed under the MIT License.

## References

- **stKAIA Protocol**: https://github.com/stakely-protocol/stakely-core
- **K-bit PerpDEX**: https://github.com/devKBit/k-bit
- **ERC4626 Standard**: https://eips.ethereum.org/EIPS/eip-4626
- **OpenZeppelin Contracts**: https://github.com/OpenZeppelin/openzeppelin-contracts
