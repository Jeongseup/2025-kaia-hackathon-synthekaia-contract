// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IStKaia
 * @dev Interface for the stKAIA liquid staking contract. I made the interface functions via https://github.com/stakely-protocol/stakely-core/blob/main/contracts/StKlay.sol#L133
 */
interface IStKaia {
    function stake() external payable;

    function stakeFor(address recipient) external payable;

    function unstake(uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);
}
