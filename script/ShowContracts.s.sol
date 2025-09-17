// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {StkaiaDeltaNeutralVault} from "../src/StkaiaDeltaNeutralVault.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {Utility} from "./Utility.s.sol";

/**
 * @title ShowContracts Script
 * @notice 이미 배포된 Vault 컨트랙트의 주소를 출력합니다.
 */
contract ShowContracts is Script {
    function run() external {
        Utility utility = new Utility();
        (
            address _usdtAddress,
            address _stkaiaAddress,
            address _routerAddress,
            address _perpDexAddress,
            address _vaultImplementationAddress,
            address _vaultProxy
        ) = utility.getMostRecentDeployment("DeployVault");

        console.log("-------------------------------------------");
        console.log("- Show Latest Deployed Contract Addresses -");
        console.log("-------------------------------------------");

        console.log("USDT Address:", _usdtAddress);
        console.log("stKAIA Address:", _stkaiaAddress);
        console.log("Router Address:", _routerAddress);
        console.log("PerpDex Address:", _perpDexAddress);
        console.log(
            "Vault Implementation Address:",
            _vaultImplementationAddress
        );
        console.log("Vault Proxy Address:", _vaultProxy);
    }
}
