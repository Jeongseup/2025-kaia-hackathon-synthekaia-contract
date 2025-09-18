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
        10_000_000 * (10 ** STKAIA_DECIMALS); // Mock 라우터에 넉넉한 stKAIA 공급

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
        vm.startPrank(user);
        usdt.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, user);
        vm.stopPrank();

        assertTrue(shares > 0, "Shares should be issued");
        // asset(USDT, 6)과 share(6)이므로 1:1 비율로 발행됩니다.
        uint256 expectedShares = 1000 * (10 ** USDT_DECIMALS);
        assertEq(
            shares,
            expectedShares,
            "Shares should correspond to assets considering decimals"
        );
    }

    /**
     * @notice ✨ 수정됨: 동적 비율 Mock 라우터의 스왑 로직을 검증하는 테스트
     * @dev 1 USDT -> 6.02 stKAIA 비율이 올바르게 적용되는지 확인합니다.
     */
    function testDeposit_Triggers_ExecuteStrategy_WithDynamicRate() public {
        // --- 1. Arrange ---
        uint256 depositAmount = 2000 * (10 ** USDT_DECIMALS); // 2000 USDT 예치
        uint256 amountToSwap = depositAmount / 2; // 1000 USDT를 스왑
        uint256 amountToShort = depositAmount - amountToSwap;

        // Mock 라우터의 로직(1 USDT -> 6.02 stKAIA)에 따라 예상 결과값을 계산합니다.
        // 소수점 차이를 반드시 보정해야 합니다.
        uint256 scaledExpectedStKAIA = (amountToSwap * 602) / 100;
        uint256 expectedStKAIAOut = scaledExpectedStKAIA *
            (10 ** (STKAIA_DECIMALS - USDT_DECIMALS));

        console.log("--- Test: Dynamic Rate Router Swap ---");
        console.log(
            "Amount to Swap (USDT):",
            amountToSwap / (10 ** USDT_DECIMALS)
        );
        console.log(
            "Expected stKAIA Out (Human-Readable):",
            expectedStKAIAOut / (10 ** STKAIA_DECIMALS)
        );
        console.log("Expected stKAIA Out (Raw Wei):", expectedStKAIAOut);

        vm.prank(user);
        usdt.approve(address(vault), depositAmount);

        // --- 2. Act ---
        vm.expectEmit(true, true, true, true);
        emit StkaiaDeltaNeutralVault.StrategyExecuted(
            depositAmount,
            amountToSwap,
            amountToShort,
            expectedStKAIAOut
        );

        vm.prank(user);
        vault.deposit(depositAmount, user);

        // --- 3. Assert ---
        uint256 actualStkaiABalance = stKAIA.balanceOf(address(vault));
        console.log("Actual stKAIA Balance (Raw Wei):", actualStkaiABalance);
        console.log(
            "Actual stKAIA Balance (Human-Readable):",
            actualStkaiABalance / (10 ** STKAIA_DECIMALS)
        );

        assertEq(
            actualStkaiABalance,
            expectedStKAIAOut,
            "Vault should receive the correct amount of stKAIA based on dynamic rate"
        );
        console.log(
            "Assertion Passed: Vault received the correct amount of stKAIA."
        );

        assertEq(
            usdt.balanceOf(address(vault)),
            0,
            "Vault USDT balance should be 0 after strategy execution"
        );
        console.log("Assertion Passed: Vault USDT balance is 0.");

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
        console.log("Assertion Passed: PerpDEX call was correct.");
    }

    function test_fail_DepositZero() public {
        vm.prank(user);
        vm.expectRevert("Vault: amount must be > 0");
        vault.deposit(0, user);
    }

    /**
     * @notice ✨ 신규: deposit 이후 Vault의 상태를 조회하고 가치를 계산하는 플로우를 테스트합니다.
     * @dev 동적 비율(1 USDT -> 6.02 stKAIA) 라우터를 사용하여 테스트합니다.
     */
    function test_ReadAndCalculateVaultStatus_AfterDeposit() public {
        // --- 0. Arrange ---
        uint256 depositAmount = 2000 * (10 ** USDT_DECIMALS); // 5,000 USDT 예치

        // 사전 실행: 사용자가 approve 및 deposit을 수행합니다.
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
        console.log("Total Shares Minted (Raw):", status.totalShares);
        console.log(
            "Leftover USDT in Vault (Dust):",
            status.leftoverUsdtInVault
        );
        console.log("User Share Balance (Raw):", userShares);

        // --- 2. Vault 총 가치(TVL) 계산 시뮬레이션 ---
        console.log(
            "\n--- 2. Vault TVL Calculation (Off-Chain Simulation) ---"
        );

        // 실제 프론트엔드에서는 가격 API를 통해 이 값들을 실시간으로 받아옵니다.
        // 예: 1 stKAIA = 0.17 USDT (1/6.02 ≈ 0.166, 가격 약간 상승 가정)
        uint256 stkaiaPriceInUsdt = 17 * (10 ** (USDT_DECIMALS - 2)); // 0.17 * 1e6
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
