// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IStKaia } from "../interfaces/IStKaia.sol";

/**
 * @title MockStKaia
 * @dev Mock for the stKAIA contract for testing purposes.
 */
contract MockStKaia is IStKaia {
    mapping(address => uint256) private _balances;

    function stakeFor(address recipient) external payable override {
        _balances[recipient] += msg.value;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }
}
