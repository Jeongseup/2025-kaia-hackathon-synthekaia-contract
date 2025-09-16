// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IPerpDex } from "../interfaces/IPerpDex.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MockPerpDex
 * @dev A mock contract that simulates the behavior of the PerpDex for testing.
 */
contract MockPerpDex is IPerpDex {
    IERC20 public usdt;
    uint256 public nextPositionId = 1;

    // --- Events ---
    event PositionOpened(
        uint256 indexed positionId,
        address indexed trader,
        TokenType tokenType,
        uint256 margin,
        uint256 size,
        uint256 initialPrice,
        bool isLong,
        uint256 tpPrice,
        uint256 slPrice
    );

    // --- State ---
    mapping(uint256 => OpenPositionData) public positions;

    constructor(address _usdtAddress) {
        usdt = IERC20(_usdtAddress);
    }

    /**
     * @notice Simulates opening a position. It captures the input data, stores it
     * against a new position ID, and transfers the margin from the caller.
     */
    function openPosition(OpenPositionData calldata o) external payable override {
        uint256 positionId = nextPositionId++;
        positions[positionId] = o;

        // Simulate pulling the margin from the HybridStrategyManager contract.
        if (o.marginAmount > 0) {
            usdt.transferFrom(msg.sender, address(this), o.marginAmount);
        }

        // Emit an event to mimic the real contract's behavior.
        emit PositionOpened(
            positionId,
            o.trader,
            o.tokenType,
            o.marginAmount,
            o.marginAmount * o.leverage, // Mock size calculation
            o.expectedPrice,
            o.long,
            o.tpPrice,
            o.slPrice
        );
    }
}
