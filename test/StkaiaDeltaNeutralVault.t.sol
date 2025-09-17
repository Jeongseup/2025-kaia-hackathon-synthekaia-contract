// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {console} from "forge-std/Script.sol";
import {StkaiaDeltaNeutralVault} from "../../src/StkaiaDeltaNeutralVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockUniswapV3Router} from "./mocks/MockUniswapV3Router.sol";
import {MockPerpDex} from "./mocks/MockPerpDex.sol";
import {IPerpDex} from "../../src/interfaces/IPerpDex.sol";

/**
 * @title StkaiaDeltaNeutralVault 테스트 스위트
 * @notice StkaiaDeltaNeutralVault 컨트랙트의 주요 기능을 테스트합니다.
 */
contract StkaiaDeltaNeutralVaultTest is Test {
    StkaiaDeltaNeutralVault internal vault; // 프록시 주소를 가리키게 될 변수
    StkaiaDeltaNeutralVault internal vaultImplementation; // 구현 컨트랙트 주소

    MockERC20 internal usdt;
    MockERC20 internal stKAIA;
    MockUniswapV3Router internal router;
    MockPerpDex internal perpDex;

    address internal owner;
    address internal user;

    // 토큰별 소수점 자리수 정의
    uint256 internal constant USDT_DECIMALS = 6;
    uint256 internal constant STKAIA_DECIMALS = 18;
    uint256 internal constant SHARE_DECIMALS = 18; // ERC4626 쉐어 토큰의 소수점

    uint256 internal constant INITIAL_USER_BALANCE =
        1_000_000 * (10 ** USDT_DECIMALS); // 1,000,000 USDT
    uint256 internal constant INITIAL_ROUTER_STKAIA_BALANCE =
        1_000_000 * (10 ** STKAIA_DECIMALS);

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");

        // 1. Mock 컨트랙트들 배포
        usdt = new MockERC20("Tether", "USDT", uint8(USDT_DECIMALS));
        stKAIA = new MockERC20("Staked KAIA", "stKAIA", uint8(STKAIA_DECIMALS));
        router = new MockUniswapV3Router();
        perpDex = new MockPerpDex();

        // 2. Vault 구현 컨트랙트 배포
        vaultImplementation = new StkaiaDeltaNeutralVault();

        // 3. 프록시 배포 및 초기화
        bytes memory initData = abi.encodeWithSelector(
            StkaiaDeltaNeutralVault.initialize.selector,
            address(usdt),
            address(stKAIA),
            address(router),
            address(perpDex),
            owner
        );
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(vaultImplementation),
            initData
        );
        vault = StkaiaDeltaNeutralVault(address(proxy));

        // 4. 테스트 환경 설정
        usdt.mint(user, INITIAL_USER_BALANCE);
        stKAIA.mint(address(router), INITIAL_ROUTER_STKAIA_BALANCE);
        perpDex.setUsdt(address(usdt));
    }

    /**
     * @notice 사용자가 deposit을 호출했을 때 올바른 수량의 쉐어가 발행되는지 테스트합니다.
     */
    function testDeposit_IssuesShares() public {
        uint256 depositAmount = 1000 * (10 ** USDT_DECIMALS);

        // 사용자가 볼트에 USDT 사용을 승인합니다.
        vm.startPrank(user);
        usdt.approve(address(vault), depositAmount);

        // 사용자가 deposit을 호출합니다.
        uint256 shares = vault.deposit(depositAmount, user);
        vm.stopPrank();

        // 발행된 쉐어 수량이 0보다 큰지 확인합니다.
        // 첫 입금이므로 자산과 쉐어는 1:1 비율이어야 합니다.
        assertTrue(shares > 0);
        assertEq(
            shares,
            depositAmount,
            "Shares should be equal to assets on initial deposit"
        );

        // 사용자의 USDT 잔액이 감소했는지 확인합니다.
        assertEq(
            usdt.balanceOf(user),
            INITIAL_USER_BALANCE - depositAmount,
            "User USDT balance should decrease"
        );
    }

    /**
     * @notice 사용자의 deposit이 _executeStrategy를 올바르게 트리거하는지 테스트합니다.
     */
    function testDeposit_Triggers_ExecuteStrategy() public {
        // --- 1. Arrange ---
        uint256 depositAmount = 2000 * (10 ** USDT_DECIMALS);
        uint256 amountToSwap = depositAmount / 2;
        uint256 amountToShort = depositAmount - amountToSwap;

        // Mock Uniswap 라우터가 스왑의 결과로 반환할 stKAIA 수량을 설정합니다.
        // 1 USDT = 0.98 stKAIA 라고 가정
        uint256 expectedStKAIAOut = ((amountToSwap * 98) / 100) *
            (10 ** (STKAIA_DECIMALS - USDT_DECIMALS));
        router.setExpectedAmountOut(expectedStKAIAOut);

        // 유저가 볼트 컨트랙트에 입금할 금액을 approve합니다.
        vm.prank(user);
        usdt.approve(address(vault), depositAmount);

        // --- 2. Act ---

        // StrategyExecuted 이벤트가 올바른 파라미터로 발생하는지 검사하도록 설정합니다.
        vm.expectEmit(true, true, true, true);
        emit StkaiaDeltaNeutralVault.StrategyExecuted(
            depositAmount,
            amountToSwap,
            amountToShort,
            expectedStKAIAOut
        );

        // 유저가 deposit 함수를 호출합니다.
        vm.prank(user);
        vault.deposit(depositAmount, user);

        // --- 3. Assert ---

        // Vault가 스왑 결과로 stKAIA를 받았는지 확인합니다.
        assertEq(
            stKAIA.balanceOf(address(vault)),
            expectedStKAIAOut,
            "Vault should receive stKAIA after swap"
        );

        // Vault의 USDT 잔액이 0인지 확인합니다 (전략에 모두 사용되었으므로).
        assertEq(
            usdt.balanceOf(address(vault)),
            0,
            "Vault USDT balance should be 0 after strategy execution"
        );

        // Mock PerpDex의 상태를 확인하여 openPosition이 올바른 값으로 호출되었는지 검증합니다.
        IPerpDex.OpenPositionData memory lastPosition = perpDex
            .getLastOpenPositionData();
        assertEq(
            lastPosition.marginAmount,
            amountToShort,
            "PerpDex marginAmount is incorrect"
        );
        assertEq(
            uint256(lastPosition.tokenType),
            uint256(IPerpDex.TokenType.Klay),
            "PerpDex tokenType is incorrect"
        );
        assertEq(lastPosition.long, false, "Position should be short");
    }

    /**
     * @notice test_fail_DepositZero: 0개의 자산을 예치하려고 할 때 실패하는지 테스트합니다.
     */
    function test_fail_DepositZero() public {
        // deposit 함수는 0개의 자산을 예치할 경우 revert되어야 합니다.
        vm.prank(user);
        vm.expectRevert("Vault: amount must be > 0");
        vault.deposit(0, user);
    }

    /**
     * @notice ✨ 신규: deposit 이후 Vault의 상태를 조회하고 가치를 계산하는 플로우를 테스트합니다.
     */
    function test_ReadAndCalculateVaultStatus_AfterDeposit() public {
        // --- 0. Arrange ---
        uint256 depositAmount = 2000 * (10 ** USDT_DECIMALS); // 2,000 USDT 예치
        uint256 amountToSwap = depositAmount / 2;

        // 1 USDT = 0.98 stKAIA 라고 가정, 소수점 보정
        uint256 expectedStKAIAOut = ((amountToSwap * 98) / 100) *
            (10 ** (STKAIA_DECIMALS - USDT_DECIMALS));
        router.setExpectedAmountOut(expectedStKAIAOut);

        vm.startPrank(user);
        usdt.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user);
        vm.stopPrank();

        console.log("==============================================");
        console.log("======= Simulating Frontend Logic in Foundry =======");
        console.log("==============================================");

        // --- 1. 온체인 데이터 가져오기 (Raw Data) ---
        console.log("\n--- 1. On-Chain Data (Raw) ---");
        StkaiaDeltaNeutralVault.VaultStatus memory status = vault
            .getVaultStatus();
        uint256 userShares = vault.balanceOf(user);

        // 가독성을 위해 소수점을 제외한 값으로 출력
        console.log(
            "Total USDT Ever Deposited:",
            status.totalUsdtEverDeposited / (10 ** USDT_DECIMALS)
        );
        console.log(
            "Total USDT Currently Shorted:",
            status.totalUsdtCurrentlyShorted / (10 ** USDT_DECIMALS)
        );
        console.log(
            "Current stKAIA Balance:",
            status.currentStkAIABalance / (10 ** STKAIA_DECIMALS)
        );
        console.log("Total Shares Minted:", status.totalShares);
        console.log(
            "Leftover USDT in Vault (Dust):",
            status.leftoverUsdtInVault
        );
        console.log("User Share Balance:", userShares);

        // --- 2. Vault 총 가치(TVL) 계산 시뮬레이션 ---
        console.log(
            "\n--- 2. Vault TVL Calculation (Off-Chain Simulation) ---"
        );

        // 실제 프론트엔드에서는 가격 API를 통해 이 값들을 실시간으로 받아옵니다.
        // 예: 1 stKAIA = 1.02 USDT (가격 상승 가정)
        uint256 stkaiaPriceInUsdt = 102 * (10 ** (USDT_DECIMALS - 2)); // 1.02 * 1e6
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
            "   => Vault Total Value Locked (TVL):",
            totalVaultValueInUsdt / (10 ** USDT_DECIMALS),
            "USDT"
        );

        // --- 3. 사용자 보유 자산 가치 계산 ---
        console.log("\n--- 3. User Asset Value Calculation ---");

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
                "Value Per Share (in USDT):",
                valuePerShare / (10 ** USDT_DECIMALS)
            );
            console.log(
                "   => User's Asset Value:",
                userValueInUsdt / (10 ** USDT_DECIMALS),
                "USDT"
            );
        }

        console.log("\n==============================================");
    }
}
