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
        address WKAIA_ADDRESS = vm.envAddress("WKAIA_ADDRESS");
        address INITIAL_OWNER = msg.sender;

        vm.startBroadcast();
        HybridStrategyManager manager = new HybridStrategyManager(
            ST_KAIA_ADDRESS,
            PERP_DEX_ADDRESS,
            KLAY_SWAP_ADDRESS,
            USDT_ADDRESS,
            WKAIA_ADDRESS,
            INITIAL_OWNER
        );
        vm.stopBroadcast();
        
        console.log("HybridStrategyManager deployed at:", address(manager));
        return manager;
    }
}