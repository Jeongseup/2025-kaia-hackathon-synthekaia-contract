// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {HybridStrategyManager} from "../src/HybridStrategyManager.sol";
import {MockStKaia} from "../src/test/MockStKaia.sol";
import {MockPerpDex} from "../src/test/MockPerpDex.sol";
import {MockKlaySwap} from "../src/test/MockKlaySwap.sol";

contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "mUSDT") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract HybridStrategyManagerTest is Test {
    HybridStrategyManager public manager;
    MockStKaia public mockStKaia;
    MockPerpDex public mockPerpDex;
    MockKlaySwap public mockKlaySwap;
    MockUSDT public mockUsdt;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        mockStKaia = new MockStKaia();
        mockUsdt = new MockUSDT();
        mockPerpDex = new MockPerpDex(address(mockUsdt));
        mockKlaySwap = new MockKlaySwap(address(mockUsdt));
        manager = new HybridStrategyManager(
            address(mockStKaia),
            address(mockPerpDex),
            address(mockKlaySwap),
            address(mockUsdt),
            address(mockUsdt), // mock wKAIA address
            owner
        );

        console.log("Owner address:", owner);
        console.log("User address:", user);
        console.log("Manager address:", address(manager));
    }

    function test_deposit_ExecutesBothStrategiesCorrectly() public {
        uint256 totalDeposit = 100 ether;
        vm.deal(user, totalDeposit);

        // Expected results
        uint256 expectedStakeAmount = totalDeposit / 2;

        // Simulate user depositing funds
        vm.broadcast(user);
        manager.deposit{value: totalDeposit}();

        // Result 1: Half of the deposit is staked in StKaia
        assertEq(manager.totalKaiADeposited(), totalDeposit);
        assertEq(manager.userTotalDeposits(user), totalDeposit);
        assertEq(mockStKaia.balanceOf(address(user)), expectedStakeAmount);

        // Result 2: Half of the deposit is used to open a position on PerpDex
    }
}
