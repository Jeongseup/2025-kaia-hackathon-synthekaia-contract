# Makefile for the SyntheKaia Project

# Load environment variables from .env file.
# The script will fail gracefully if .env does not exist.
-include .env

# --- Configuration ---
# Default values that can be overridden in the .env file or via the shell.
# e.g., make deploy KAIA_RPC_URL=https://my-custom-rpc.com
KAIA_RPC_URL ?= "YOUR_KAIA_RPC_URL_HERE"
PRIVATE_KEY ?= "YOUR_PRIVATE_KEY_HERE"
TEST_USER_ADDRESS ?= "YOUR_TEST_USER_ADDRESS_HERE"

# The addresses for ST_KAIA, PERP_DEX, etc., are read directly by the
# deploy script from the .env file, so they don't need to be defined here.

# Set the default command to 'help'
.DEFAULT_GOAL := help

# Phony targets are not real files
.PHONY: help deploy build test clean fmt

help:
	@echo "Usage:"
	@echo "  make deploy      Deploy the StkaiaDeltaNeutralVault contract and dependencies."
	@echo "  make build        Compile the smart contracts."
	@echo "  make test         Run the Foundry test suite."
	@echo "  make clean        Remove the build artifacts and cache."
	@echo "  make fmt          Format the Solidity code using forge fmt."

read-vault-status:
	@echo "Reading vault status..."
	@forge script script/ReadVaultStatus.s.sol:ReadVaultStatus \
		--rpc-url $(KAIA_RPC_URL) \
		-vvv
		
show-contracts:
	@echo "Showing deployed contract addresses..."
	@forge script script/ShowContracts.s.sol:ShowContracts \
		--rpc-url $(KAIA_RPC_URL) 

interact:
	@echo "Interacting with the deployed vault..."
	@forge script script/InteractWithVault.s.sol:InteractWithVault \
		--rpc-url $(KAIA_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast -vvvv

CONTRACT_ADDRESS ?= 0xee85600aab576a8f80d392E25886fbDBd7f8BF38
CONTRACT_NAME ?= StkaiaDeltaNeutralVault
COMPILER_VERSION ?= 0.8.30

verify-contract:
	@echo "Verifying contract on Kaiascan..."
	@forge flatten src/StkaiaDeltaNeutralVault.sol > Flattened.sol
	@forge verify-contract \
		--verifier-url https://kairos-api.kaiascan.io/forge-verify-flatten \
		--chain-id 1001 \
		--compiler-version ${COMPILER_VERSION} ${CONTRACT_ADDRESS} Flattened.sol:${CONTRACT_NAME} --retries 1

balances:
	@echo "Checking balances..."
	@forge script script/Balances.s.sol:Balances \
		--rpc-url $(KAIA_RPC_URL) \
		-v

deploy:
	@# Check if essential variables are set before proceeding.
	@if [ -z "$(KAIA_RPC_URL)" ] || [ "$(KAIA_RPC_URL)" = "YOUR_KAIA_RPC_URL_HERE" ]; then \
		echo "Error: KAIA_RPC_URL is not set. Please define it in your .env file."; \
		exit 1; \
	fi
	@if [ -z "$(PRIVATE_KEY)" ] || [ "$(PRIVATE_KEY)" = "YOUR_PRIVATE_KEY_HERE" ]; then \
		echo "Error: PRIVATE_KEY is not set. Please define it in your .env file."; \
		exit 1; \
	fi
	@if [ -z "$(TEST_USER_ADDRESS)" ]; then \
		echo "Error: TEST_USER_ADDRESS is not set. Please define it in your .env file."; \
		exit 1; \
	fi
	@echo "Deploying StkaiaDeltaNeutralVault contract and dependencies..."
	@# Execute the vault deployment script using configured variables.
	@forge script script/DeployVault.s.sol:DeployVault \
		--rpc-url $(KAIA_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast -vvvv

build:
	@echo "Building contracts..."
	@forge build

test:
	@echo "Running tests..."
	@forge test -vvv

clean:
	@echo "Cleaning build artifacts..."
	@forge clean

fmt:
	@echo "Formatting Solidity files..."
	@forge fmt
