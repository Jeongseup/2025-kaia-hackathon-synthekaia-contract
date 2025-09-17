// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {StkaiaDeltaNeutralVault} from "../src/StkaiaDeltaNeutralVault.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {Utility} from "./Utility.s.sol";

/**
 * @title InteractWithVault Script
 * @notice 이미 배포된 Vault 컨트랙트에 deposit을 실행합니다.
 * @dev 이 스크립트는 컨트랙트를 배포하지 않으며, 주소를 인자로 받아야 합니다.
 */
contract InteractWithVault is Script {
    // 테스트 유저가 입금할 금액
    uint256 public constant DEPOSIT_AMOUNT = 10 * 1e6;

    function run() external {
        // --- 1. 상호작용 준비 ---
        // .env 파일에서 테스트 유저의 private key를 읽어옵니다.
        uint256 testUserPrivateKey = vm.envUint("PRIVATE_KEY");
        address testUserAddress = vm.addr(testUserPrivateKey);

        // 가장 최근에 실행된 DeployAll.s.sol 스크립트의 배포 정보를 가져옵니다.
        // Utilities.s.sol 헬퍼 컨트랙트를 사용하여 broadcast 로그에서 컨트랙트 주소를 읽어옵니다.
        Utility utility = new Utility();
        (address _usdtAddress, , , , , address _vaultProxy) = utility
            .getMostRecentDeployment("DeployVault");

        console.log("-----------------------------------------");
        console.log("Starting interaction with deployed contracts...");
        console.log("-----------------------------------------");
        console.log("Vault Proxy Address:", _vaultProxy);
        console.log("USDT Address:", _usdtAddress);
        console.log("Interacting with user account:", testUserAddress);

        // 배포된 컨트랙트 주소로 컨트랙트 인스턴스를 생성합니다.
        StkaiaDeltaNeutralVault vault = StkaiaDeltaNeutralVault(_vaultProxy);
        MockERC20 usdt = MockERC20(_usdtAddress);

        // --- 2. 테스트 유저로 트랜잭션 브로드캐스팅 시작 ---
        vm.startBroadcast(testUserPrivateKey);

        // --- 2-1. Approve ---
        console.log(
            "Approving Vault to spend",
            DEPOSIT_AMOUNT / 1e6,
            "mUSDT..."
        );
        usdt.approve(_vaultProxy, DEPOSIT_AMOUNT);
        console.log("-> Approve transaction sent.");

        // --- 2-2. Deposit ---
        console.log("Depositing", DEPOSIT_AMOUNT / 1e18, "mUSDT into Vault...");
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, testUserAddress);
        console.log("-> Deposit transaction sent.");
        console.log("-> Received", shares / 1e18, "shares.");

        // --- 2-3. 상호작용 후 상태 확인 (선택사항) ---
        uint256 userUsdtBalance = usdt.balanceOf(testUserAddress);
        console.log("-> Final user mUSDT balance:", userUsdtBalance / 1e18);

        uint256 vaultShareBalance = vault.balanceOf(testUserAddress);
        console.log("-> Final user share balance:", vaultShareBalance / 1e18);

        // --- 3. 브로드캐스팅 종료 ---
        vm.stopBroadcast();

        console.log("Interaction script finished successfully!");
    }
}
