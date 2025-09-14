// SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../src/HybridStrategyManager.sol";
import "../src/test/MockStKaia.sol";
import "../src/test/MockPerpDex.sol";
import "../src/test/MockKlaySwap.sol";

contract MockUSDT is ERC20 {
constructor() ERC20("Mock USDT", "mUSDT") {}
function mint(address to, uint256 amount) public { _mint(to, amount); }
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
            owner
        );
    }

    function test_deposit_ExecutesBothStrategiesCorrectly() public {
        uint256 totalDeposit = 100 ether;
        vm.deal(user, totalDeposit);
        uint256 expectedStakeAmount = totalDeposit / 2;
        uint256 expectedSwapAmount = totalDeposit - expectedStakeAmount;
        uint256 expectedUsdtReceived = (expectedSwapAmount * mockKlaySwap.KAIA_TO_USDT_RATE()) / 1 ether;

        vm.prank(user);
        manager.deposit{value: totalDeposit}();

        assertEq(manager.totalKaiADeposited(), totalDeposit);
        assertEq(manager.userTotalDeposits(user), totalDeposit);
        assertEq(mockStKaia.balanceOf(address(manager)), expectedStakeAmount);
        assertEq(address(mockPerpDex).balance, 0); // PerpDex receives USDT, not KAIA
        assertEq(mockUsdt.balanceOf(address(mockPerpDex)), expectedUsdtReceived);
    }

    function test_UpdateProtocolAddresses_Success() public {
        address newStKaia = makeAddr("newStKaia");
        address newPerpDex = makeAddr("newPerpDex");
        address newKlaySwap = makeAddr("newKlaySwap");
        address newUsdt = makeAddr("newUsdt");

        vm.prank(owner);
        manager.updateProtocolAddresses(newStKaia, newPerpDex, newKlaySwap, newUsdt);

        assertEq(address(manager.stKaia()), newStKaia);
        assertEq(address(manager.perpDex()), newPerpDex);
        assertEq(address(manager.klaySwap()), newKlaySwap);
        assertEq(address(manager.usdt()), newUsdt);
    }

    function test_Fail_UpdateProtocolAddresses_NotOwner() public {
        address newStKaia = makeAddr("newStKaia");
        address newPerpDex = makeAddr("newPerpDex");
        address newKlaySwap = makeAddr("newKlaySwap");
        address newUsdt = makeAddr("newUsdt");

        vm.prank(user); // Non-owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        manager.updateProtocolAddresses(newStKaia, newPerpDex, newKlaySwap, newUsdt);
    }

}
