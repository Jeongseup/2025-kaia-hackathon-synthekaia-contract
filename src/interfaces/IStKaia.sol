// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
- @title IStKaia
- @dev Interface for the stKAIA liquid staking contract.
  */
  interface IStKaia {
  function stake() external payable;
  function stakeFor(address recipient) external payable;
  function balanceOf(address account) external view returns (uint256);
  }