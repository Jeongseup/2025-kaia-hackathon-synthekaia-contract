# SynteKaia: Hybrid DeFi Strategy Vault

SynteKaia is a decentralized finance (DeFi) smart contract built on the Kaia network that automates a sophisticated investment strategy. It takes a user's deposited KAIA and automatically splits it 50/50 into two strategies to generate yield and hedge against market risk simultaneously.

## Core Strategy

When a user deposits KAIA into the `HybridStrategyManager` contract, the funds are automatically allocated to two strategies within a single transaction:

1.  **Liquid Staking (50%)**: Half of the KAIA is staked into the **stKAIA protocol**. This generates continuous, stable staking rewards while the contract holds the liquid `stKAIA` token.
2.  **Perpetual Short Position (50%)**: The other half is swapped for **USDT** on a DEX (e.g., KlaySwap). This USDT is then used as collateral to open a leveraged short position (3x) on Bitcoin (BTC) at a perpetuals exchange (PerpDEX). This serves as a hedge against potential market downturns.

## Tech Stack

- **Smart Contracts**: Solidity
- **Development Framework**: Foundry

## Project Structure

The project is organized with a focus on modularity and testability:

```
.
├── src
│   ├── HybridStrategyManager.sol  # The core logic contract.
│   ├── interfaces/                # Interfaces for all external protocols (stKAIA, PerpDEX, etc.).
│   └── test/                      # Mock contracts for isolated testing.
├── test
│   └── HybridStrategyManager.t.sol  # Foundry tests for the main contract.
├── script
│   └── DeployHybridStrategyManager.s.sol # Deployment script.
├── lib/                             # Dependencies (Forge-std, OpenZeppelin).
├── Makefile                         # Shortcuts for common commands.
└── foundry.toml                     # Foundry configuration.
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
ST_KAIA_ADDRESS="0x..."
PERP_DEX_ADDRESS="0x..."
KLAY_SWAP_ADDRESS="0x..."
USDT_ADDRESS="0x..."
```

**Important**: You must replace the placeholder values with the actual addresses of the protocols on your target network and your personal wallet information.

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
  Deploy the `HybridStrategyManager` contract to the network specified in your `.env` file. This command will fail with an error if `KAIA_RPC_URL` or `PRIVATE_KEY` are not set.

## Testing

To run the full test suite and ensure the contract logic is sound:

```bash
make test
```

## Deployment

1.  Ensure your `.env` file is correctly configured with your private key, RPC URL, and the correct protocol addresses for your target network.
2.  Run the deployment command:

    ```bash
    make deploy
    ```

3.  If successful, the address of your newly deployed `HybridStrategyManager` contract will be printed to the console. You can now use this address and the contract's ABI (found in `out/HybridStrategyManager.sol/HybridStrategyManager.json`) to interact with it from a frontend dApp.

## License

This project is licensed under the MIT License.

## References

- stKAIA Contract: https://github.com/stakely-protocol/stakely-core/tree/main
- perpDEX Contract: https://github.com/devKBit/k-bit
