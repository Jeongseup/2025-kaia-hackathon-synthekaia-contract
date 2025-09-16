// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IUniswapV3Router} from "./interfaces/IUniswapV3Router.sol";
import {IPerpDex} from "./interfaces/IPerpDex.sol";

/**
 * @title StkaiaDeltaNeutralVault
 * @author EVM Master Virtuoso
 * @notice 이 볼트는 USDT를 예치받아 stKAIA 현물 보유와 K-bit 파생상품 숏 포지션을 결합한
 * 델타 중립 전략을 수행하여 수익을 창출하는 것을 목표로 합니다.
 * 이 컨트랙트는 ERC4626 표준을 따르는 업그레이드 가능한 볼트입니다.
 */
contract StkaiaDeltaNeutralVault is
    Initializable,
    ERC4626Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    // --- 외부 컨트랙트 인터페이스 ---
    IUniswapV3Router public uniswapRouter;
    IPerpDex public perpDex;
    IERC20 public stKAIA;

    // --- 전략 설정 변수 ---
    uint24 public swapFee; // Uniswap V3 풀의 수수료 (e.g., 3000 for 0.3%)
    uint256 public leverage; // 숏 포지션 레버리지 (e.g., 2 * 1e18 for 2x)
    IPerpDex.TokenType public perpDexTokenType; // K-bit DEX에서 거래할 토큰 타입

    // --- 이벤트 ---
    event StrategyExecuted(
        uint256 totalUsdtAmount,
        uint256 amountSwapped,
        uint256 amountShorted,
        uint256 stKAIAAmountReceived
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice 컨트랙트 초기화 함수 (업그레이드 가능한 컨트랙트의 생성자 역할)
     * @param _asset USDT 토큰 주소
     * @param _stKAIA stKAIA 토큰 주소
     * @param _uniswapRouter Uniswap V3 또는 호환 라우터 주소
     * @param _perpDex K-bit 파생상품 DEX 주소
     * @param _initialOwner 컨트랙트의 초기 소유자 주소
     */
    function initialize(
        address _asset, // USDT
        address _stKAIA,
        address _uniswapRouter,
        address _perpDex,
        address _initialOwner
    ) public initializer {
        __ERC4626_init(IERC20(_asset));
        __ERC20_init("Stkaia Delta Neutral Vault Share", "sdnVS");
        __Ownable_init(_initialOwner);
        __Pausable_init();
        __ReentrancyGuard_init();

        stKAIA = IERC20(_stKAIA);
        uniswapRouter = IUniswapV3Router(_uniswapRouter);
        perpDex = IPerpDex(_perpDex);

        swapFee = 3000;
        leverage = 2 * 1e18;
        perpDexTokenType = IPerpDex.TokenType.Klay;
    }

    /**
     * @notice 사용자가 USDT를 볼트에 예치하고 그에 상응하는 쉐어 토큰을 받습니다.
     * @dev ERC4626의 deposit 함수를 오버라이드합니다.
     * 입금 후 내부적으로 _executeStrategy 함수를 호출하여 델타 중립 전략을 수행합니다.
     * @param assets 예치할 USDT의 양
     * @param receiver 쉐어 토큰을 받을 주소
     * @return shares 발행된 쉐어 토큰의 양
     */
    function deposit(
        uint256 assets,
        address receiver
    ) public override nonReentrant whenNotPaused returns (uint256 shares) {
        require(assets > 0, "Vault: amount must be > 0");

        // ERC4626 표준에 따라 입금을 처리하고 쉐어를 계산합니다.
        // 부모 컨트랙트의 deposit 함수를 `super`로 호출하여 쉐어를 반환받습니다.
        shares = super.deposit(assets, receiver);

        // 입금된 자금으로 투자 전략을 실행합니다.
        IPerpDex.OraclePrices memory emptyOraclePrices;
        _executeStrategy(assets, emptyOraclePrices);
    }

    /**
     * @notice 예치된 USDT를 사용하여 델타 중립 전략을 수행하는 내부 함수
     * @dev 50% USDT -> stKAIA 스왑, 50% USDT -> PerpDEX 숏 포지션 오픈
     * @param _usdtAmount 전략을 수행할 USDT의 총량
     * @param _oraclePrices 숏 포지션 오픈에 필요한 오라클 데이터
     */
    function _executeStrategy(
        uint256 _usdtAmount,
        IPerpDex.OraclePrices memory _oraclePrices
    ) internal {
        require(_usdtAmount > 0, "Vault: amount must be > 0");

        // 1. 입금된 USDT의 절반(amountToSwap)과 나머지 절반(amountToShort)을 계산합니다.
        uint256 amountToSwap = _usdtAmount / 2;
        uint256 amountToShort = _usdtAmount - amountToSwap;

        IERC20 usdt = IERC20(asset());

        // 2. Uniswap V3 라우터를 통해 USDT를 stKAIA로 스왑합니다.
        // 2-1. 라우터에 USDT 사용을 승인합니다.
        usdt.approve(address(uniswapRouter), 0);
        usdt.approve(address(uniswapRouter), amountToSwap);

        // 2-2. 스왑 파라미터를 준비하고 실행합니다.
        IUniswapV3Router.ExactInputSingleParams memory params = IUniswapV3Router
            .ExactInputSingleParams({
                tokenIn: address(usdt),
                tokenOut: address(stKAIA),
                fee: swapFee,
                recipient: address(this),
                amountIn: amountToSwap,
                amountOutMinimum: 0, // TODO: 프로덕션에서는 슬리피지 보호를 위해 0이 아닌 값을 사용해야 합니다.
                sqrtPriceLimitX96: 0
            });
        uint256 stKAIAAmountReceived = uniswapRouter.exactInputSingle(params);

        // 3. 나머지 절반의 USDT로 K-bit perpDEX에서 숏 포지션을 오픈합니다.
        if (amountToShort > 0) {
            // 3-1. PerpDEX에 USDT 사용을 승인합니다.
            usdt.approve(address(perpDex), 0);
            usdt.approve(address(perpDex), amountToShort);

            // 3-2. 숏 포지션 오픈 파라미터를 준비하고 실행합니다.
            IPerpDex.OpenPositionData memory posData = IPerpDex
                .OpenPositionData({
                    tokenType: perpDexTokenType,
                    marginAmount: amountToShort,
                    leverage: leverage,
                    long: false, // 숏 포지션
                    trader: address(this),
                    priceData: _oraclePrices, // TODO: 프로덕션에서는 신뢰할 수 있는 외부 소스로부터 받아야 합니다.
                    tpPrice: 0,
                    slPrice: 0,
                    expectedPrice: 0,
                    userSignedData: ""
                });
            perpDex.openPosition(posData);
        }

        emit StrategyExecuted(
            _usdtAmount,
            amountToSwap,
            amountToShort,
            stKAIAAmountReceived
        );
    }

    /**
     * @notice 볼트가 보유한 총 자산의 가치를 반환합니다.
     * @dev ERC4626 표준 함수 오버라이드.
     * 현재는 예치된 USDT의 잔액만 반환합니다.
     * 정확한 가치 평가를 위해서는 보유한 stKAIA와 숏 포지션의 가치를
     * USDT로 환산하여 합산하는 로직이 추가되어야 합니다.
     * @return 총 자산 가치 (USDT 기준)
     */
    function totalAssets() public view override returns (uint256) {
        // TODO: stKAIA 잔액 가치와 숏 포지션 PnL을 포함한 전체 자산 가치를 계산해야 합니다.
        return IERC20(asset()).balanceOf(address(this));
    }

    // --- 추가적인 볼트 관리 함수 (향후 구현) ---
    // withdraw, mint, redeem 등의 ERC4626 함수들도 필요에 따라 오버라이드하여
    // 전략 청산 로직(_liquidateStrategy)과 연동해야 합니다.

    //     function _buildShortPositionData(uint256 _usdtMargin, address _trader) internal pure returns (IPerpDex.OpenPositionData memory) {
    //     IPerpDex.OraclePrices memory prices; // Empty for testing
    //     return IPerpDex.OpenPositionData({
    //         tokenType: IPerpDex.TokenType.Btc,
    //         marginAmount: _usdtMargin,
    //         leverage: 3,
    //         long: false,
    //         trader: _trader,
    //         priceData: prices,
    //         tpPrice: 0,
    //         slPrice: 0,
    //         expectedPrice: 0,
    //         userSignedData: ""
    //     });
    // }
}
