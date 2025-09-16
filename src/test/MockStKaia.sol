// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import {IStKaia} from "../interfaces/IStKaia.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockStKaia
 * @dev Mock for the stKAIA contract for testing purposes. Inherits from ERC20 to behave like a real token.
 */
contract MockStKaia is IStKaia, ERC20 {
    event Staked(address indexed recipient, uint256 amount);

    constructor() ERC20("Mock stKAIA", "mstKAIA") {}

    function stakeFor(address recipient) external payable override {
        _mint(recipient, msg.value);
        emit Staked(recipient, msg.value);
    }

    function stake() external payable override {
        // 1. something internal staking logic
        // _stake()

        // 2. mint mock stKAIA token and send to staker
        super._mint(tx.origin, msg.value);

        // 3. emit event
        emit Staked(tx.origin, msg.value);
    }

    function balanceOf(
        address account
    ) public view override(IStKaia, ERC20) returns (uint256) {
        return super.balanceOf(account);
    }
}
