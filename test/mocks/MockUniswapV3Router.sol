// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// ✨ FIX: 토큰의 decimals() 함수를 호출하기 위해 ERC20 컨트랙트를 import 합니다.
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV3Router} from "../../src/interfaces/IUniswapV3Router.sol";

/**
 * @title MockUniswapV3Router (Dynamic Decimals)
 * @notice 실제 토큰 전송과 동적 소수점 변환을 시뮬레이션하는 유연한 Uniswap V3 Router의 모의 컨트랙트입니다.
 */
contract MockUniswapV3Router is IUniswapV3Router {
    /**
     * @notice exactInputSingle 함수의 Mock 구현
     * @dev 1 tokenIn 당 6.02 tokenOut의 교환 비율을 동적으로 소수점 차이를 보정하여 시뮬레이션합니다.
     */
    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut) {
        // ✨ FIX: tokenIn과 tokenOut의 소수점을 하드코딩하는 대신 동적으로 조회합니다.
        uint256 tokenInDecimals = ERC20(params.tokenIn).decimals();
        uint256 tokenOutDecimals = ERC20(params.tokenOut).decimals();

        // 1. 비율을 곱합니다: (amountIn * 602) / 100
        uint256 scaledAmountOut = (params.amountIn * 602) / 100;

        // 2. 동적으로 조회한 소수점 차이를 보정합니다.
        if (tokenOutDecimals > tokenInDecimals) {
            amountOut =
                scaledAmountOut *
                (10 ** (tokenOutDecimals - tokenInDecimals));
        } else {
            amountOut =
                scaledAmountOut /
                (10 ** (tokenInDecimals - tokenOutDecimals));
        }

        // 1. Vault로부터 tokenIn을 가져옵니다.
        IERC20(params.tokenIn).transferFrom(
            msg.sender,
            address(this),
            params.amountIn
        );

        // 2. Vault에게 계산된 tokenOut을 전송합니다.
        IERC20(params.tokenOut).transfer(params.recipient, amountOut);

        // 3. 계산된 수량을 반환합니다.
        return amountOut;
    }
}
