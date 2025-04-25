// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {CommunityChest} from "../src/CommunityChest.sol";

contract CommunityChestTest is Test {
    CommunityChest public chest;

    address public communityMemberA = makeAddr("communityMemberA");

    function setUp() public {
        chest = new CommunityChest();
    }

    function testDeposit() public {
        chest.deposit{value: 100}(100);
        assertEq(chest.getBalance(), 100);
    }

    function testDepositInvalidAmount() public {
        vm.expectRevert(CommunityChest.InvalidAmount.selector);
        chest.deposit{value: 100}(101);
    }

    function testWithdraw() public {
        chest.deposit{value: 100}(100);

        vm.prank(communityMemberA);
        chest.withdraw(100);
        assertEq(chest.getBalance(), 0);
    }

    function testWithdrawInsufficientBalance() public {
        vm.prank(communityMemberA);
        bytes4 s = CommunityChest.TransferUnsuccessful.selector;
        vm.expectRevert(
            abi.encodeWithSelector(s, 100)
        );
        chest.withdraw(100);
    }
}
