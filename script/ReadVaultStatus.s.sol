// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {StkaiaDeltaNeutralVault} from "../src/StkaiaDeltaNeutralVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Utility} from "./Utility.s.sol";

/**
 * @title ReadVaultStatus Script
 * @notice 배포된 StkaiaDeltaNeutralVault의 현재 상태와 가치를 조회하고 계산하여 출력합니다.
 * @dev 이 스크립트는 읽기 전용이며, 트랜잭션을 생성하지 않습니다.
 */
contract ReadVaultStatus is Script {
    // 토큰별 소수점 자리수를 상수로 정의하여 가독성을 높입니다.
    uint256 private constant USDT_DECIMALS = 6;
    uint256 private constant STKAIA_DECIMALS = 18;
    uint256 private constant SHARE_DECIMALS = 18;

    function run() external {
        // 가장 최근에 실행된 DeployAll.s.sol 스크립트의 배포 정보를 가져옵니다.
        // Utilities.s.sol 헬퍼 컨트랙트를 사용하여 broadcast 로그에서 컨트랙트 주소를 읽어옵니다.
        Utility utility = new Utility();
        (address _usdtAddress, , , , , address _vaultProxyAddress) = utility
            .getMostRecentDeployment("DeployVault");
        address testUserAddress = vm.envAddress("TEST_USER_ADDRESS");

        console.log("-----------------------------------------");
        console.log("Starting interaction with deployed contracts...");
        console.log("-----------------------------------------");
        console.log("Vault Proxy Address:", _vaultProxyAddress);
        console.log("USDT Address:", _usdtAddress);
        console.log("Interacting with user account:", testUserAddress);

        // 제공된 주소를 사용하여 Vault 컨트랙트 인스턴스를 생성합니다.
        StkaiaDeltaNeutralVault vault = StkaiaDeltaNeutralVault(
            _vaultProxyAddress
        );

        console.log("==============================================");
        console.log("======= Vault Status Dashboard (Simulation) =======");
        console.log("==============================================");
        console.log("Vault Address:", _vaultProxyAddress);
        console.log("User Address:", testUserAddress);

        // --- 1. 온체인 데이터 가져오기 (Raw Data) ---
        console.log("\n--- 1. Fetching On-Chain Raw Data ---");
        StkaiaDeltaNeutralVault.VaultStatus memory status = vault
            .getVaultStatus();
        uint256 userShares = vault.balanceOf(testUserAddress);

        console.log(
            "Total USDT Ever Deposited (Calculated):",
            status.totalUsdtEverDeposited / (10 ** USDT_DECIMALS),
            "USDT"
        );
        console.log(
            "Total USDT in Short Positions (Calculated):",
            status.totalUsdtCurrentlyShorted / (10 ** USDT_DECIMALS),
            "USDT"
        );
        console.log(
            "Current stKAIA Balance (Calculated):",
            status.currentStkAIABalance / (10 ** STKAIA_DECIMALS),
            "stKAIA"
        );
        console.log("Total Shares Minted (Raw):", status.totalShares);
        console.log(
            "Leftover USDT in Vault (Dust) (Raw):",
            status.leftoverUsdtInVault
        );
        console.log("User Share Balance (Raw):", userShares);

        // --- 2. Vault 총 가치(TVL) 계산 시뮬레이션 ---
        console.log(
            "\n--- 2. Calculating Vault TVL (Off-Chain Simulation) ---"
        );

        // 실제 프론트엔드에서는 가격 API를 통해 이 값들을 실시간으로 받아옵니다.
        // 예: 1 stKAIA = 1.02 USDT (가격 상승 가정) -> 1 stKAIA = 0.1643

        uint256 stkaiaPriceInUsdt = 1643 * (10 ** (USDT_DECIMALS - 4)); // 1.02 * 1e6
        // 예: 숏 포지션의 가치가 5% 상승했다고 가정 (수익 발생)
        uint256 shortPositionPnlMultiplier = 105; // 1.05 -> 105 / 100

        // stKAIA의 가치를 USDT 기준으로 계산
        uint256 stkaiaValueInUsdt = (status.currentStkAIABalance *
            stkaiaPriceInUsdt) / (10 ** STKAIA_DECIMALS);
        // 숏 포지션의 가치를 USDT 기준으로 계산
        uint256 shortPositionValueInUsdt = (status.totalUsdtCurrentlyShorted *
            shortPositionPnlMultiplier) / 100;
        // 볼트의 총 가치 (TVL) 계산
        uint256 totalVaultValueInUsdt = stkaiaValueInUsdt +
            shortPositionValueInUsdt +
            status.leftoverUsdtInVault;

        console.log("   - Mock stKAIA Price: 1.02 USDT");
        console.log("   - Mock Short PnL: +5.00%");
        console.log(
            "   - stKAIA Value (in USDT):",
            stkaiaValueInUsdt / (10 ** USDT_DECIMALS)
        );
        console.log(
            "   - Short Position Value (in USDT):",
            shortPositionValueInUsdt / (10 ** USDT_DECIMALS)
        );
        console.log("   ----------------------------------------");
        console.log(
            "   => Total Vault Value (TVL):",
            totalVaultValueInUsdt / (10 ** USDT_DECIMALS),
            "USDT"
        );

        // --- 3. 사용자 보유 자산 가치 계산 ---
        console.log("\n--- 3. Calculating User's Asset Value ---");

        if (status.totalShares == 0) {
            console.log("No shares have been minted yet.");
        } else {
            // 쉐어 1개의 현재 가치를 계산합니다. (USDT 기준)
            // 정밀도 유지를 위해 큰 수에 먼저 곱하고 나중에 나눕니다.
            uint256 valuePerShare = (totalVaultValueInUsdt *
                (10 ** SHARE_DECIMALS)) / status.totalShares;

            // 사용자의 총 자산 가치를 계산합니다.
            uint256 userValueInUsdt = (userShares * valuePerShare) /
                (10 ** SHARE_DECIMALS);

            console.log(
                "Value per Share (in USDT):",
                valuePerShare / (10 ** USDT_DECIMALS)
            );
            console.log(
                "   => User's Holdings Value:",
                userValueInUsdt / (10 ** USDT_DECIMALS),
                "USDT"
            );
        }

        console.log("\n==============================================");
    }
}
