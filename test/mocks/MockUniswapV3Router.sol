// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IUniswapV3Router} from "../../src/interfaces/IUniswapV3Router.sol";

/**
 * @title MockUniswapV3Router
 * @notice 테스트를 위한 Uniswap V3 Router의 모의 컨트랙트입니다.
 * 인터페이스의 함수 시그니처만 만족시키며, 실제 로직은 없습니다.
 */
contract MockUniswapV3Router is IUniswapV3Router {
    function exactInputSingle(
        ExactInputSingleParams calldata /*params*/
    ) external payable returns (uint256 amountOut) {
        // 현재는 deposit 테스트만 하므로 실제 스왑 로직은 필요 없습니다.
        // 향후 _executeStrategy를 테스트할 때, 여기서 모의 반환값을 설정할 수 있습니다.
        return 0;
    }

    // IUniswapV3Router 인터페이스의 다른 함수들도 필요하다면 여기에 추가할 수 있습니다.
}
