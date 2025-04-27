// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {TipJar} from "../src/TipJar.sol";

contract TipJarTest is StdInvariant, Test {
    TipJar public jar;
    TipJarHandler public handler;

    address public owner = makeAddr("owner");
    address public tipper = makeAddr("tipper");
    address public tipper2 = makeAddr("tipper2");

    uint256 constant startingBalance = 10 ether;

    function setUp() public {
        jar = new TipJar();
        jar.changeOwner(owner);

        handler = new TipJarHandler(jar, owner);

        vm.deal(owner, startingBalance);
        vm.deal(tipper, startingBalance);
        vm.deal(tipper2, startingBalance);
    }

    function testDeposit() public {
        vm.prank(tipper);
        jar.deposit{value: 1 ether}(1 ether);
        assertEq(jar.getBalance(), 1 ether);
    }

    function testDepositInvalidAmount() public {
        vm.prank(tipper);
        vm.expectRevert(TipJar.InvalidAmount.selector);
        jar.deposit{value: 1 ether}(2 ether);
    }

    function testWithdraw() public {
        vm.prank(tipper);
        jar.deposit{value: 1 ether}(1 ether);
        assertEq(jar.getBalance(), 1 ether);

        vm.prank(owner);
        jar.withdraw(1 ether);
        assertEq(jar.getBalance(), 0);
    }

    function testWithdrawUnauthorized() public {
        vm.prank(tipper);
        jar.deposit{value: 1 ether}(1 ether);
        assertEq(jar.getBalance(), 1 ether);

        vm.prank(tipper2);
        vm.expectRevert(TipJar.Unauthorized.selector);
        jar.withdraw(1 ether);
    }

    function testWithdrawUnsuccessful() public {
        vm.prank(tipper);
        jar.deposit{value: 1 ether}(1 ether);
        assertEq(jar.getBalance(), 1 ether);

        bytes4 s = TipJar.WithdrawUnsuccessful.selector;
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(s, 2 ether)
        );
        jar.withdraw(2 ether);
    }

    function testChangeOwner() public {
        vm.prank(owner);
        jar.changeOwner(tipper);
        assertEq(jar.owner(), tipper);
    }

    function testChangeOwnerUnauthorized() public {
        vm.prank(tipper);
        vm.expectRevert(TipJar.Unauthorized.selector);
        jar.changeOwner(tipper);
    }

    function testDepositWithCall() public {
        vm.prank(tipper);
        (bool success, ) = address(jar).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(jar.getBalance(), 1 ether);
    }
    
    function testMoreThanOneTipperAndOwnerWithdraws() public {
        vm.prank(tipper);
        jar.deposit{value: 1 ether}(1 ether);
        assertEq(jar.getBalance(), 1 ether);

        vm.prank(tipper2);
        jar.deposit{value: 1 ether}(1 ether);
        assertEq(jar.getBalance(), 2 ether);

        vm.prank(owner);
        jar.withdraw(0.5 ether);
        assertEq(jar.getBalance(), 1.5 ether);

        uint256 remainingBalance = jar.getBalance();
        vm.prank(owner);
        jar.withdraw(remainingBalance);
        assertEq(jar.getBalance(), 0);
    }

    function testDepositZeroAmount() public {
        vm.prank(tipper);
        jar.deposit{value: 0}(0);
        assertEq(jar.getBalance(), 0);
    }

    function testWithdrawZeroAmount() public {
        vm.prank(owner);
        jar.withdraw(0);
        assertEq(jar.getBalance(), 0);
    }

    function testChangeOwnerToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(TipJar.ZeroAddress.selector);
        jar.changeOwner(address(0));
    }

    function testChangeOwnerToExistingOwner() public {
        vm.prank(owner);
        jar.changeOwner(owner);
        assertEq(jar.owner(), owner);
    }

    function testWithdrawInsufficientContractBalance() public {
        vm.prank(tipper);
        jar.deposit{value: 1 ether}(1 ether);
        
        // Withdraw more than contract balance
        vm.prank(owner);
        bytes4 s = TipJar.WithdrawUnsuccessful.selector;
        vm.expectRevert(
            abi.encodeWithSelector(s, 2 ether)
        );
        jar.withdraw(2 ether);

        assertEq(jar.getBalance(), 1 ether);
    }

    function testWithdrawAfterOwnershipChange() public {
        vm.prank(tipper);
        jar.deposit{value: 1 ether}(1 ether);
        
        vm.prank(owner);
        jar.changeOwner(tipper);
        
        // Previous owner should not be able to withdraw
        vm.prank(owner);
        vm.expectRevert(TipJar.Unauthorized.selector);
        jar.withdraw(1 ether);
        
        // New owner should be able to withdraw
        vm.prank(tipper);
        jar.withdraw(1 ether);
        assertEq(jar.getBalance(), 0);
    }

    function testFuzzDeposit(uint256 amount) public {
        vm.assume(amount <= startingBalance);
        vm.prank(tipper);
        jar.deposit{value: amount}(amount);
        assertEq(jar.getBalance(), amount);
    }
    
    function testFuzzWithdraw(uint256 amount) public {
        vm.assume(amount <= startingBalance);
        vm.prank(tipper);
        jar.deposit{value: amount}(amount);

        vm.prank(owner);
        jar.withdraw(amount);
        assertEq(jar.getBalance(), 0);
    }

    function invariantNonNegativeBalance() public view {
        assert(jar.getBalance() >= 0);
    }

    function invariantOwnerHasControl() public {
        vm.prank(jar.owner());
        (bool success,) = address(jar).call(
            abi.encodeWithSignature("withdraw(uint256)", 0)
        );
        assert(success);
    }

    function invariantNonZeroOwner() public view {
        assert(jar.owner() != address(0));
    }
}

// For invariant testing that needs to track state
contract TipJarHandler {
    TipJar private jar;
    address private currentOwner;

    constructor(TipJar _jar, address _initialOwner) {
        jar = _jar;
        currentOwner = _initialOwner;
    }

    function changeOwner(address newOwner) external {
        if (msg.sender == currentOwner) {
            jar.changeOwner(newOwner);
            currentOwner = newOwner;
        }
    }

    function getCurrentOwner() external view returns (address) {
        return currentOwner;
    }
}

contract TipJarInvariantTestWithHandler is StdInvariant, Test {
    TipJar public jar;
    TipJarHandler public handler;
    address public owner = makeAddr("owner");
    address public tipper = makeAddr("tipper");

    function setUp() public {
        jar = new TipJar();
        jar.changeOwner(owner);
        handler = new TipJarHandler(jar, owner);

        targetContract(address(handler));
    }

    function invariantOwnerSync() public view {
        assert(jar.owner() == handler.getCurrentOwner());
    }
}
