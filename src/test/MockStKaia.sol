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

    function stake() external payable override {
        // 1. something internal staking logic
        // _stake()

        // 2. mint mock stKAIA token and send to staker
        _mint(msg.sender, msg.value);

        // 3. emit event
        emit Staked(msg.sender, msg.value);
    }

    function stakeFor(address recipient) external payable override {
        // 1. something internal staking logic
        // _stake()

        // 2. mint mock stKAIA token and send to staker
        _mint(recipient, msg.value);

        // 3. emit event
        emit Staked(recipient, msg.value);
    }

    function unstake(uint256 amount) external override {
        // 1. burn mock stKAIA token from sender
        super._burn(msg.sender, amount);

        // 2. something internal unstaking logic
        // _unstake()

        // 3. send KLAY back to sender
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "KLAY transfer failed");
    }

    function balanceOf(
        address account
    ) public view override(IStKaia, ERC20) returns (uint256) {
        return super.balanceOf(account);
    }
}
