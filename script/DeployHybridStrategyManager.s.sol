// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { HybridStrategyManager } from "../src/HybridStrategyManager.sol";

contract DeployHybridStrategyManager is Script {
    function run() external returns (HybridStrategyManager) {
        // --- IMPORTANT: Replace these with actual addresses on your target network ---
        // You can use environment variables for better security and flexibility.
        address stKaiaAddress = vm.envAddress("ST_KAIA_ADDRESS"); // e.g., 0xF80F2b22932fCEC6189b9153aA18662b15CC9C00
        address perpDexAddress = vm.envAddress("PERP_DEX_ADDRESS");
        address klaySwapAddress = vm.envAddress("KLAY_SWAP_ADDRESS");
        address usdtAddress = vm.envAddress("USDT_ADDRESS");
        address initialOwner = msg.sender;

        vm.startBroadcast();

        HybridStrategyManager manager = new HybridStrategyManager(
            stKaiaAddress,
            perpDexAddress,
            klaySwapAddress,
            usdtAddress,
            initialOwner
        );

        vm.stopBroadcast();

        console.log("HybridStrategyManager deployed at:", address(manager));
        return manager;
    }
}
