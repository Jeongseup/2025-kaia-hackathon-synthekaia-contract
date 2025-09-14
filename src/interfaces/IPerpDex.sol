// SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;

/**
- @title IPerpDex
- @dev Simplified interface for the PerpDex contract.
  */
  interface IPerpDex {
  enum TokenType { Btc, Klay, Wemix, Eth, Doge, Pepe, Sol, Xrp, Apt, Sui, Shib, Sei, Ada, Pol, Bnb, Dot, Ltc, Avax, Trump }
  enum OracleType { BisonAI, Pyth }

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

      function openPosition(OpenPositionData calldata o) external payable;

  }