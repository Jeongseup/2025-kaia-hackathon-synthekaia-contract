// script/Balances.s.sol

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Utility} from "./Utility.s.sol";

contract Balances is Script {
    function run() external {
        // .env 파일에서 배포자의 private key와 테스트 유저 주소를 읽어옵니다.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        // ✨ FIX: .env 파일에서 테스트 유저 주소를 읽어옵니다.
        address testUserAddress = vm.envAddress("TEST_USER_ADDRESS");

        // 가장 최근에 실행된 DeployAll.s.sol 스크립트의 배포 정보를 가져옵니다.
        // Utilities.s.sol 헬퍼 컨트랙트를 사용하여 broadcast 로그에서 컨트랙트 주소를 읽어옵니다.
        Utility utility = new Utility();
        (address mUSDT, address mstKAIA) = utility.getMostRecentDeployment(
            "DeployVault"
        );
        require(
            mUSDT != address(0) && mstKAIA != address(0),
            "Deployment not found. Run deployment script first."
        );

        console.log("Last Deployed mUSDT Address: ", mUSDT);
        console.log("Last Deployed mstKAIA Address: ", mstKAIA);

        // --- mUSDT 잔액 확인 ---
        uint256 mUSDTDeployerBalance = IERC20(mUSDT).balanceOf(deployerAddress);
        uint256 mUSDTUserBalance = IERC20(mUSDT).balanceOf(testUserAddress);

        // --- mstKAIA 잔액 확인 ---
        uint256 mstKAIADeployerBalance = IERC20(mstKAIA).balanceOf(
            deployerAddress
        );
        uint256 mstKAIAUserBalance = IERC20(mstKAIA).balanceOf(testUserAddress);

        console.log("--- Balance Check ---");
        console.log(
            "Deployer's mUSDT Balance:  ",
            mUSDTDeployerBalance / 1e6,
            "mUSDT"
        );
        console.log(
            "User's mUSDT Balance:      ",
            mUSDTUserBalance / 1e6,
            "mUSDT"
        );
        console.log("---------------------");
        console.log(
            "Deployer's mstKAIA Balance: ",
            mstKAIADeployerBalance / 1e18,
            "mstKAIA"
        );
        console.log(
            "User's mstKAIA Balance:     ",
            mstKAIAUserBalance / 1e18,
            "mstKAIA"
        );
        console.log("---------------------");
    }
}
