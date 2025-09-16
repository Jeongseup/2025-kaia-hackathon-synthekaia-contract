// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title K-bit PerpDex 인터페이스
 * @notice K-bit 파생상품 DEX와의 상호작용을 위한 함수와 자료구조를 정의합니다.
 * @dev 실제 PerpDex.sol의 구조체와 함수 시그니처를 기반으로 작성되었습니다.
 */
interface IPerpDex {
    // PerpDex.sol에서 사용하는 Enum과 Struct를 가져옵니다.
    // 실제 프로젝트에서는 별도의 라이브러리 파일로 분리하는 것이 더 좋습니다.
    enum TokenType {
        Btc,
        Klay,
        Wemix,
        Eth,
        Doge,
        Pepe,
        Sol,
        Xrp,
        Apt,
        Sui,
        Shib,
        Sei,
        Ada,
        Pol,
        Bnb,
        Dot,
        Ltc,
        Avax,
        Trump
    }

    enum OracleType {
        BisonAI,
        Pyth
    }

    struct OraclePrices {
        OracleType oracleType;
        bytes32[] feedHashes;
        int256[] answers;
        uint256[] timestamps;
        bytes[] proofs;
    }

    struct OpenPositionData {
        TokenType tokenType;
        uint256 marginAmount;
        uint256 leverage;
        bool long;
        address trader;
        OraclePrices priceData;
        uint256 tpPrice;
        uint256 slPrice;
        uint256 expectedPrice;
        bytes userSignedData;
    }

    /**
     * @notice 새로운 포지션을 오픈합니다.
     * @param o 포지션 오픈에 필요한 데이터
     */
    function openPosition(OpenPositionData calldata o) external payable;
}
