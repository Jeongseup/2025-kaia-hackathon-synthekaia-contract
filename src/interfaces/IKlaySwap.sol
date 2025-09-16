// SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;

/**
- @title IKlaySwap
- @dev Simplified interface for a DEX like KlaySwap.
  */
  interface IKlaySwap {
  function swapExactKlayForTokens(
  uint amountOutMin,
  address[] calldata path,
  address to,
  uint deadline
  ) external payable returns (uint[] memory amounts);
  }