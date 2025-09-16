// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPerpDex} from "../../src/interfaces/IPerpDex.sol";

/**
 * @title MockPerpDex
 * @notice 테스트를 위한 K-bit PerpDEX의 모의 컨트랙트입니다.
 * 인터페이스의 함수 시그니처만 만족시키며, 실제 로직은 없습니다.
 */
contract MockPerpDex is IPerpDex {
    function openPosition(
        address, // _token
        uint256, // _amount
        uint256, // _leverage
        bool // _isLong
    ) external {
        // 현재는 deposit 테스트만 하므로 실제 포지션 오픈 로직은 필요 없습니다.
    }

    // IPerpDex 인터페이스의 다른 함수들도 필요하다면 여기에 추가할 수 있습니다.
}
