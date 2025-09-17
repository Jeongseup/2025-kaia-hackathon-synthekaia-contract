// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// 배포에 필요한 모든 컨트랙트들을 import 합니다.
import {StkaiaDeltaNeutralVault} from "../src/StkaiaDeltaNeutralVault.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {MockUniswapV3Router} from "../test/mocks/MockUniswapV3Router.sol";
import {MockPerpDex} from "../test/mocks/MockPerpDex.sol";

/**
 * @title DeployVault Script
 * @notice StkaiaDeltaNeutralVault와 의존성 Mock 컨트랙트들을 배포합니다.
 */
contract DeployVault is Script {
    struct DeploymentAddresses {
        address vaultProxy;
        address usdt;
        address stKAIA;
        address router;
        address perpDex;
    }

    // --- 토큰 소수점 상수 ---
    uint256 private constant USDT_DECIMALS = 6;
    uint256 private constant STKAIA_DECIMALS = 18;

    function run()
        external
        returns (
            address vaultProxy,
            address usdt,
            address stKAIA,
            address router,
            address perpDex
        )
    {
        DeploymentAddresses memory addresses = _deployContracts();

        vaultProxy = addresses.vaultProxy;
        usdt = addresses.usdt;
        stKAIA = addresses.stKAIA;
        router = addresses.router;
        perpDex = addresses.perpDex;
    }

    function _deployContracts()
        internal
        returns (DeploymentAddresses memory addresses)
    {
        // .env 파일에서 배포자의 private key와 테스트 유저 주소를 읽어옵니다.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        // ✨ FIX: .env 파일에서 테스트 유저 주소를 읽어옵니다.
        address testUserAddress = vm.envAddress("TEST_USER_ADDRESS");

        // 배포 트랜잭션 브로드캐스팅을 시작합니다.
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying contracts with account:", deployerAddress);
        console.log("Test user address set to:", testUserAddress);

        // --- 1. Mock 컨트랙트 배포 ---
        console.log("Deploying Mock USDT...");
        MockERC20 mockUsdt = new MockERC20(
            "Mock Tether",
            "mUSDT",
            uint8(USDT_DECIMALS)
        );
        addresses.usdt = address(mockUsdt);
        console.log("-> Mock USDT deployed at:", addresses.usdt);

        console.log("Deploying Mock stKAIA...");
        MockERC20 mockStKAIA = new MockERC20(
            "Mock Staked KAIA",
            "mstKAIA",
            uint8(STKAIA_DECIMALS)
        );
        addresses.stKAIA = address(mockStKAIA);
        console.log("-> Mock stKAIA deployed at:", addresses.stKAIA);

        console.log("Deploying Mock Uniswap Router...");
        MockUniswapV3Router mockRouter = new MockUniswapV3Router();
        addresses.router = address(mockRouter);
        console.log("-> Mock Uniswap Router deployed at:", addresses.router);

        console.log("Deploying Mock PerpDEX...");
        MockPerpDex mockPerpDex = new MockPerpDex();
        addresses.perpDex = address(mockPerpDex);
        console.log("-> Mock PerpDEX deployed at:", addresses.perpDex);

        // --- 2. Vault 구현 컨트랙트 배포 ---
        console.log("Deploying Vault Implementation...");
        StkaiaDeltaNeutralVault vaultImplementation = new StkaiaDeltaNeutralVault();
        address implementationAddress = address(vaultImplementation);
        console.log(
            "-> Vault Implementation deployed at:",
            implementationAddress
        );

        // --- 3. 프록시 배포 및 초기화 ---
        console.log("Preparing initialization data for proxy...");
        bytes memory initData = abi.encodeWithSelector(
            StkaiaDeltaNeutralVault.initialize.selector,
            addresses.usdt,
            addresses.stKAIA,
            addresses.router,
            addresses.perpDex,
            deployerAddress // 배포자가 초기 소유자가 됩니다.
        );

        console.log("Deploying ERC1967Proxy for Vault...");
        ERC1967Proxy proxy = new ERC1967Proxy(implementationAddress, initData);
        addresses.vaultProxy = address(proxy);
        console.log("-> Vault Proxy deployed at:", addresses.vaultProxy);

        // --- 4. 배포 후 Mock 컨트랙트 설정 ---
        console.log("Configuring Mock Contracts...");
        // mockRouter.setStKAIA(addresses.stKAIA);
        mockPerpDex.setUsdt(addresses.usdt);

        uint256 MOCK_ROUTER_STKAIA_BALANCE = 1_000_000 * 1e18;
        mockStKAIA.mint(addresses.router, MOCK_ROUTER_STKAIA_BALANCE);
        console.log(
            "-> Minted",
            MOCK_ROUTER_STKAIA_BALANCE / 1e18,
            "stKAIA to Mock Router"
        );

        // --- ✨ 수정된 부분: 1 mUSDT -> 0.1641 stKAIA 비율로 스왑 결과 설정 ---
        console.log("Configuring mock swap rate: 1 mUSDT -> 0.1641 stKAIA");
        // 이 설정은 실제로 스왑되는 양과 무관하게, 라우터가 따를 '교환 비율'을 설정하는 것입니다.
        // Vault가 1000 mUSDT를 스왑하면, 164.1 stKAIA를 받게 됩니다.
        uint256 amountToSwap = 1_000_000 * (10 ** USDT_DECIMALS); // 1,000,000 mUSDT 기준

        // expectedStKAIAOut = (1,000,000 * 10**6) * (1641 / 10000) * (10**12)
        // 정밀도 유지를 위해 곱셈을 먼저 수행합니다.
        uint256 expectedStKAIAOut = (amountToSwap *
            1641 *
            (10 ** (STKAIA_DECIMALS - USDT_DECIMALS))) / 10000;
        mockRouter.setExpectedAmountOut(expectedStKAIAOut); // 실제로는 Vault가 스왑하는 양에 따라 이 값이 동적으로 계산되어야 하지만, Mock에서는 이 비율을 따르도록 설정합니다.
        console.log(
            "-> Mock Router is now configured to return stKAIA at the specified rate."
        );

        // ✨ FIX: 테스트 유저와 개발자 주소로 초기 자금(mUSDT)을 민팅합니다. 둘 주소 전부 테스트 시나리오에 사용될 수 있도록 합니다.
        console.log("Minting initial funds to test user...");
        uint256 INITIAL_USER_BALANCE = 1_000_000 * 1e6;
        mockUsdt.mint(testUserAddress, INITIAL_USER_BALANCE);
        console.log(
            "-> Minted",
            INITIAL_USER_BALANCE / 1e6,
            "mUSDT to:",
            testUserAddress
        );
        mockUsdt.mint(deployerAddress, INITIAL_USER_BALANCE);
        console.log(
            "-> Minted",
            INITIAL_USER_BALANCE / 1e6,
            "mUSDT to:",
            deployerAddress
        );

        console.log("Deployment and configuration complete.");

        // 브로드캐스팅을 종료합니다.
        vm.stopBroadcast();
    }
}
