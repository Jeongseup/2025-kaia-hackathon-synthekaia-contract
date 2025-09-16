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
	@forge test

clean:
	@echo "Cleaning build artifacts..."
	@forge clean

fmt:
	@echo "Formatting Solidity files..."
	@forge fmt
