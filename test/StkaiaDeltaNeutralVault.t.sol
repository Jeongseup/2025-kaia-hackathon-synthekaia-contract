// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StkaiaDeltaNeutralVault} from "../src/StkaiaDeltaNeutralVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockUniswapV3Router} from "./mocks/MockUniswapV3Router.sol";
import {MockPerpDex} from "./mocks/MockPerpDex.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract StkaiaDeltaNeutralVaultTest is Test {
    // --- 상태 변수 ---
    StkaiaDeltaNeutralVault public vault;
    MockERC20 public usdt;
    MockERC20 public stKAIA;
    MockUniswapV3Router public router;
    MockPerpDex public perpDex;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    // USDT는 6-decimals
    uint256 public constant DEPOSIT_AMOUNT = 1000 * 1e6;

    /**
     * @notice 각 테스트 실행 전에 실행되는 설정 함수
     */
    function setUp() public {
        // 1. Mock 컨트랙트들 배포
        usdt = new MockERC20("Tether", "USDT", 6);
        stKAIA = new MockERC20("Staked KAIA", "stKAIA", 18);
        router = new MockUniswapV3Router();
        perpDex = new MockPerpDex();

        // 2. 업그레이드 가능한 컨트랙트를 프록시 패턴으로 배포하고 초기화합니다.

        // 2-1. 로직(구현) 컨트랙트를 먼저 배포합니다.
        StkaiaDeltaNeutralVault implementation = new StkaiaDeltaNeutralVault();

        // 2-2. 프록시에 전달할 초기화 함수 호출 데이터를 생성합니다.
        // abi.encodeWithSelector를 사용하여 `initialize(...)` 함수를 호출하는 calldata를 만듭니다.
        bytes memory initData = abi.encodeWithSelector(
            StkaiaDeltaNeutralVault.initialize.selector,
            address(usdt),
            address(stKAIA),
            address(router),
            address(perpDex),
            owner
        );

        // 2-3. 프록시 컨트랙트를 배포하고, 구현 컨트랙트 주소와 초기화 데이터를 전달합니다.
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        // 2-4. 테스트에서는 프록시 주소를 StkaiaDeltaNeutralVault 타입으로 사용합니다.
        // 이렇게 하면 모든 호출이 프록시를 통해 구현 컨트랙트로 전달됩니다.
        vault = StkaiaDeltaNeutralVault(address(proxy));

        // 4. 테스트 유저에게 USDT 민팅
        usdt.mint(user, DEPOSIT_AMOUNT);
    }

    /**
     * @notice test_deposit: 사용자가 성공적으로 USDT를 예치하는 케이스를 테스트합니다.
     */
    function test_Deposit() public {
        // --- 1. Arrange (준비) ---
        // 유저가 볼트 컨트랙트에 자신의 USDT를 사용할 수 있도록 approve 합니다.
        vm.prank(user);
        usdt.approve(address(vault), DEPOSIT_AMOUNT);

        // --- 2. Act (실행) ---
        // 유저가 deposit 함수를 호출합니다.
        vm.prank(user);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, user);

        // --- 3. Assert (검증) ---
        // 3-1. 유저의 USDT 잔액이 0이 되었는지 확인
        assertEq(usdt.balanceOf(user), 0, "User USDT balance should be 0");

        // 3-2. 볼트의 USDT 잔액이 DEPOSIT_AMOUNT와 일치하는지 확인
        assertEq(
            usdt.balanceOf(address(vault)),
            DEPOSIT_AMOUNT,
            "Vault USDT balance should be DEPOSIT_AMOUNT"
        );

        // 3-3. 유저가 받은 쉐어(shares)의 양이 올바른지 확인
        // 첫 입금자이므로, 자산(USDT)과 쉐어는 1:1 비율이어야 합니다.
        assertEq(
            shares,
            DEPOSIT_AMOUNT,
            "Returned shares should be DEPOSIT_AMOUNT"
        );
        assertEq(
            vault.balanceOf(user),
            DEPOSIT_AMOUNT,
            "User vault share balance should be DEPOSIT_AMOUNT"
        );

        // 3-4. 볼트의 총 자산(totalAssets)이 올바르게 계산되었는지 확인
        assertEq(
            vault.totalAssets(),
            DEPOSIT_AMOUNT,
            "Vault totalAssets should be DEPOSIT_AMOUNT"
        );
    }

    /**
     * @notice test_fail_DepositZero: 0개의 자산을 예치하려고 할 때 실패하는지 테스트합니다.
     */
    function test_fail_DepositZero() public {
        // deposit 함수는 0개의 자산을 예치할 경우 revert되어야 합니다.
        // (ERC4626 표준에서는 0-asset deposit을 허용할 수도 있지만, _executeStrategy 에서는 0보다 커야 하므로 여기서 막히는 것이 합리적입니다.)
        vm.prank(user);
        vm.expectRevert("Vault: amount must be > 0");
        vault.deposit(0, user);
    }
}
