// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/HybridStrategyManager.sol";

contract DeployHybridStrategyManager is Script {
    function run() external returns (HybridStrategyManager) {
        // --- IMPORTANT: Replace these with actual addresses on your target network ---
        // You can use environment variables for better security and flexibility.
        address ST_KAIA_ADDRESS = vm.envAddress("ST_KAIA_ADDRESS"); // e.g., 0xF80F2b22932fCEC6189b9153aA18662b15CC9C00
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