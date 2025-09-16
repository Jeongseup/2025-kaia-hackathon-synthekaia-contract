// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Uniswap V3 라우터 인터페이스
 * @notice Uniswap V3 및 호환 DEX와의 상호작용을 위한 핵심 함수들을 정의합니다.
 * @dev 실제 Uniswap V3의 ISwapRouter02.sol 인터페이스의 일부입니다.
 */
interface IUniswapV3Router {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /**
     * @notice 정확한 입력 수량으로 단일 풀에서 토큰을 스왑합니다.
     * @param params 스왑에 필요한 파라미터들
     * @return amountOut 받은 출력 토큰의 양
     */
    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);

    // 필요에 따라 exactInput, exactOutput, exactOutputSingle 등의 다른 함수들도 추가할 수 있습니다.
}
