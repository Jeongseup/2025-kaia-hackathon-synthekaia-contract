// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStKaia} from "./interfaces/IStKaia.sol";
import {IPerpDex} from "./interfaces/IPerpDex.sol";
import {IKlaySwap} from "./interfaces/IKlaySwap.sol";

/**
- @title HybridStrategyManager
- @notice Manages a hybrid DeFi strategy: 50% liquid staking and 50% shorting on a PerpDEX.
- @dev Owner can update external protocol addresses for future extensibility.
  */
contract HybridStrategyManager is Ownable, ReentrancyGuard {
    // --- External Protocol Contracts ---
    IStKaia public stKaia;
    IPerpDex public perpDex;
    IKlaySwap public klaySwap;
    IERC20 public usdt;
    address public wkaia;

    // --- State Variables ---
    mapping(address => uint256) public userTotalDeposits;
    uint256 public totalKaiADeposited;

    // --- Events ---
    event StrategyExecuted(
        address indexed user,
        uint256 totalDeposit,
        uint256 amountToStake,
        uint256 amountToShort
    );
    event ProtocolAddressesUpdated(
        address newStKaia,
        address newPerpDex,
        address newKlaySwap,
        address newUsdt,
        address newWkaia
    );

    constructor(
        address _stKaiaAddress,
        address _perpDexAddress,
        address _klaySwapAddress,
        address _usdtAddress,
        address _wkaiaAddress,
        address _initialOwner
    ) Ownable(_initialOwner) {
        stKaia = IStKaia(_stKaiaAddress);
        perpDex = IPerpDex(_perpDexAddress);
        klaySwap = IKlaySwap(_klaySwapAddress);
        usdt = IERC20(_usdtAddress);
        wkaia = _wkaiaAddress;
    }

    /**
     * @notice Main deposit function to execute the hybrid strategy.
     */
    function deposit() external payable nonReentrant {
        uint256 totalDeposit = msg.value;
        require(totalDeposit > 0, "Deposit must be > 0");

        uint256 amountToStake = totalDeposit / 2;
        uint256 amountToSwap = totalDeposit - amountToStake;

        // --- 1. Liquid Staking Strategy ---
        if (amountToStake > 0) {
            stKaia.stake{value: amountToStake}();
        }

        // NOTE: SKIPPED FOR TESTING PURPOSES
        // // --- 2. PerpDEX Short Strategy ---
        // if (amountToSwap > 0) {
        //     address[] memory path = new address[](2);
        //     path[0] = wkaia;
        //     path[1] = address(usdt);

        //     uint[] memory amounts = klaySwap.swapExactKlayForTokens{
        //         value: amountToSwap
        //     }(0, path, address(this), block.timestamp);
        //     uint256 usdtReceived = amounts[1];
        //     require(usdtReceived > 0, "Swap resulted in 0 USDT");

        //     usdt.approve(address(perpDex), usdtReceived);
        //     IPerpDex.OpenPositionData
        //         memory positionData = _buildShortPositionData(usdtReceived);
        //     perpDex.openPosition(positionData);
        // }

        userTotalDeposits[msg.sender] += totalDeposit;
        totalKaiADeposited += totalDeposit;

        emit StrategyExecuted(
            msg.sender,
            totalDeposit,
            amountToStake,
            amountToSwap
        );
    }

    /**
     * @notice [Owner only] Updates the addresses of the integrated external protocols.
     * @dev Allows for migrating to new contract versions or different protocols.
     * @param _newStKaia The new stKAIA contract address.
     * @param _newPerpDex The new PerpDEX contract address.
     * @param _newKlaySwap The new DEX contract address.
     * @param _newUsdt The new USDT token address.
     */
    function updateProtocolAddresses(
        address _newStKaia,
        address _newPerpDex,
        address _newKlaySwap,
        address _newUsdt,
        address _newWkaia
    ) external onlyOwner {
        require(
            _newStKaia != address(0) &&
                _newPerpDex != address(0) &&
                _newKlaySwap != address(0) &&
                _newUsdt != address(0) &&
                _newWkaia != address(0),
            "Address cannot be zero"
        );

        stKaia = IStKaia(_newStKaia);
        perpDex = IPerpDex(_newPerpDex);
        klaySwap = IKlaySwap(_newKlaySwap);
        usdt = IERC20(_newUsdt);
        wkaia = _newWkaia;

        emit ProtocolAddressesUpdated(
            _newStKaia,
            _newPerpDex,
            _newKlaySwap,
            _newUsdt,
            _newWkaia
        );
    }

    function _buildShortPositionData(
        uint256 _usdtMargin
    ) internal view returns (IPerpDex.OpenPositionData memory) {
        IPerpDex.OraclePrices memory prices; // Empty for testing
        return
            IPerpDex.OpenPositionData({
                tokenType: IPerpDex.TokenType.Btc,
                marginAmount: _usdtMargin,
                leverage: 3,
                long: false,
                trader: address(this),
                priceData: prices,
                tpPrice: 0,
                slPrice: 0,
                expectedPrice: 0,
                userSignedData: ""
            });
    }
}
