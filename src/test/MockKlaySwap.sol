// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IKlaySwap } from "../interfaces/IKlaySwap.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MockKlaySwap
 * @dev A mock contract for a DEX to simulate KAIA to USDT swaps for testing.
 */
contract MockKlaySwap is IKlaySwap {
    IERC20 public usdt;

    // A simple conversion rate for testing: 1 KAIA = 0.3 USDT (with 6 decimals).
    uint256 public constant KAIA_TO_USDT_RATE = 3 * 1e5; // 0.3 * 10^6

    constructor(address _usdtAddress) {
        usdt = IERC20(_usdtAddress);
    }

    /**
     * @notice Simulates swapping KAIA for USDT. It calculates the USDT amount based on a fixed rate
     * and transfers it to the recipient.
     */
    function swapExactKlayForTokens(
        uint amountOutMin,
        address[] calldata, // path is ignored in mock
        address to,
        uint // deadline is ignored in mock
    ) external payable override returns (uint[] memory amounts) {
        uint256 kaiaAmount = msg.value;
        uint256 usdtAmount = (kaiaAmount * KAIA_TO_USDT_RATE) / 1 ether;

        require(
            usdtAmount >= amountOutMin,
            "MockKlaySwap: Insufficient output amount"
        );

        // Mint mock USDT to this contract to simulate the swap pool.
        IMintable(address(usdt)).mint(address(this), usdtAmount);
        require(usdt.transfer(to, usdtAmount), "transfer failed");

        amounts = new uint[](2);
        amounts[0] = kaiaAmount;
        amounts[1] = usdtAmount;
        return amounts;
    }
}

// Simple interface to allow minting on a mock ERC20 token.
interface IMintable {
    function mint(address to, uint256 amount) external;
}
