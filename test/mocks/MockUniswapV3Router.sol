// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Router} from "../../src/interfaces/IUniswapV3Router.sol";

/**
 * @title MockUniswapV3Router
 * @notice 실제 토큰 전송을 시뮬레이션하는 Uniswap V3 Router의 모의 컨트랙트입니다.
 */
contract MockUniswapV3Router is IUniswapV3Router {
    uint256 public expectedAmountOut;

    /**
     * @notice 테스트에서 반환할 stKAIA의 양을 설정하는 '리모컨' 함수
     */
    function setExpectedAmountOut(uint256 _amount) external {
        expectedAmountOut = _amount;
    }

    /**
     * @notice exactInputSingle 함수의 Mock 구현
     * @dev 실제 스왑처럼 토큰 전송을 시뮬레이션합니다.
     * 1. Vault(msg.sender)로부터 USDT(params.tokenIn)를 받습니다.
     * 2. Vault(params.recipient)에게 stKAIA(stKAIA 주소)를 보냅니다.
     * 3. 미리 설정된 expectedAmountOut 값을 반환합니다.
     */
    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut) {
        // ✨ FIX: 실제 스왑처럼 행동하도록 로직을 추가합니다.
        // 1. Vault로부터 USDT를 가져옵니다.
        IERC20(params.tokenIn).transferFrom(
            msg.sender,
            address(this),
            params.amountIn
        );

        // 2. Vault에게 stKAIA를 전송합니다.
        // 이 함수가 성공하려면 이 컨트랙트(Mock Router)는 충분한 stKAIA 잔액을 가지고 있어야 합니다.
        IERC20(params.tokenOut).transfer(params.recipient, expectedAmountOut);

        // 3. 약속된 수량을 반환합니다.
        return expectedAmountOut;
    }
}
