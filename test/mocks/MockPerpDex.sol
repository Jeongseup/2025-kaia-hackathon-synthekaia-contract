// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPerpDex} from "../../src/interfaces/IPerpDex.sol";

/**
 * @title Mock K-bit PerpDex 컨트랙트
 * @notice K-bit 파생상품 DEX의 동작을 시뮬레이션하여 단위 테스트를 지원합니다.
 * @dev openPosition 호출 시 받은 데이터를 저장하여 테스트에서 검증할 수 있도록 합니다.
 */
contract MockPerpDex is IPerpDex {
    OpenPositionData public lastOpenPositionData;
    address public lastCaller;

    // 토큰(USDT)을 증거금으로 받아야 하는지 알기 위해 주소를 저장합니다.
    IERC20 internal usdt;

    /**
     * @notice 테스트에서 사용할 USDT 토큰의 주소를 설정하는 '리모컨' 함수
     */
    function setUsdt(address _usdt) external {
        usdt = IERC20(_usdt);
    }

    /**
     * @notice openPosition 함수의 Mock 구현
     * @dev Vault로부터 호출되면, 데이터를 저장하고 실제처럼 증거금을 전송받습니다.
     * @param o Vault가 전달한 포지션 오픈 데이터
     */
    function openPosition(OpenPositionData calldata o) external payable {
        lastOpenPositionData = o;
        lastCaller = msg.sender;

        // ✨ FIX: 실제 컨트랙트처럼 Vault로부터 증거금을 `transferFrom` 합니다.
        // 이 함수가 성공하려면 Vault가 이 컨트랙트 주소로 `approve`를 먼저 해두어야 합니다.
        if (address(usdt) != address(0) && o.marginAmount > 0) {
            usdt.transferFrom(msg.sender, address(this), o.marginAmount);
        }
    }

    /**
     * @notice 테스트 코드에서 마지막으로 저장된 포지션 데이터를 읽기 위한 Getter 함수
     * @dev 이 함수는 실제 IPerpDex 인터페이스에는 없으며, 오직 테스트 목적으로만 존재합니다.
     * @return 마지막으로 호출된 openPosition의 파라미터 데이터
     */
    function getLastOpenPositionData()
        external
        view
        returns (OpenPositionData memory)
    {
        return lastOpenPositionData;
    }
}
