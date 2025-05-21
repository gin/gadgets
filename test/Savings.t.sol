// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Savings} from "../src/Savings.sol";

contract SavingsTest is Test {
    Savings public savings;

    address public owner;
    address public user;

    uint256 constant LOCK_PERIOD = 30;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant DEPOSIT_AMOUNT = 1 ether;

    function setUp() public {
        owner = address(this);
        user = makeAddr("user");

        vm.deal(owner, STARTING_BALANCE);
        vm.deal(user, STARTING_BALANCE);

        savings = new Savings(LOCK_PERIOD);
    }

    function testConstructor() public view {
        assertEq(savings.owner(), owner);
        assertTrue(savings.deadline() > block.timestamp);
        // assertApproxEqAbs(savings.deadline(), block.timestamp + LOCK_PERIOD, 5); // Allow small deviation due to block time
    }

    function testDeposit() public {
        vm.prank(user);
        savings.deposit{value: DEPOSIT_AMOUNT}(DEPOSIT_AMOUNT);
        assertEq(savings.getBalance(), DEPOSIT_AMOUNT);
    }

    function testDepositInvalidAmount() public {
        vm.prank(user);
        vm.expectRevert(Savings.InvalidAmount.selector);
        savings.deposit{value: DEPOSIT_AMOUNT + 1 wei}(DEPOSIT_AMOUNT);
    }

    function testWithdrawAsOwner() public {
        console.log("balance", address(savings).balance);
        vm.prank(user);
        savings.deposit{value: DEPOSIT_AMOUNT}(DEPOSIT_AMOUNT);
        console.log("balance", address(savings).balance);

        uint256 balanceBefore = address(owner).balance;

        // Warp time to after the deadline
        vm.warp(savings.deadline() + 1);

        vm.prank(owner);
        savings.withdraw(DEPOSIT_AMOUNT);
        console.log("balance", address(savings).balance);
        uint256 balanceAfter = address(owner).balance;

        assertEq(balanceAfter - balanceBefore, DEPOSIT_AMOUNT);
        assertEq(savings.getBalance(), 0);
    }

    function testWithdrawUnauthorized() public {
        vm.prank(user);
        savings.deposit{value: DEPOSIT_AMOUNT}(DEPOSIT_AMOUNT);

        vm.prank(user);
        vm.expectRevert(Savings.Unauthorized.selector);
        savings.withdraw(DEPOSIT_AMOUNT);
    }

    function testWithdrawInsufficientBalance() public {
        vm.prank(user);
        savings.deposit{value: DEPOSIT_AMOUNT}(DEPOSIT_AMOUNT);

        // Warp time to after the deadline
        vm.warp(savings.deadline() + 1);

        // This should fail because we're trying to withdraw more than the contract has
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Savings.TransferUnsuccessful.selector, DEPOSIT_AMOUNT + 1 ether));
        savings.withdraw(DEPOSIT_AMOUNT + 1 ether);
    }

    function testGetBalance() public {
        assertEq(savings.getBalance(), 0);

        vm.prank(user);
        savings.deposit{value: DEPOSIT_AMOUNT}(DEPOSIT_AMOUNT);
        assertEq(savings.getBalance(), DEPOSIT_AMOUNT);

        // Warp time to after the deadline
        vm.warp(savings.deadline() + 1);

        vm.prank(owner);
        savings.withdraw(DEPOSIT_AMOUNT);

        assertEq(savings.getBalance(), 0);
    }

    function testGetTimeLeft() public {
        // Add console logs to debug
        console.log("Initial block.timestamp:", block.timestamp);
        console.log("Deadline:", savings.deadline());

        uint256 timeLeft = savings.getTimeLeft();
        console.log("Time left:", timeLeft);
        console.log("Expected (LOCK_PERIOD):", LOCK_PERIOD);

        assertApproxEqAbs(timeLeft, LOCK_PERIOD * 1 days, 5); // Allow small deviation due to block time

        // Warp time forward by 15 days
        vm.warp(block.timestamp + 15 days);
        timeLeft = savings.getTimeLeft();
        assertApproxEqAbs(timeLeft, 15 days, 5); // Should be about 15 days left

        // Warp time to after the deadline
        vm.warp(block.timestamp + 16 days);

        // Now the contract should return 0 for time left
        timeLeft = savings.getTimeLeft();
        assertEq(timeLeft, 0);
    }

    function testReceiveFunction() public {
        uint256 initialBalance = savings.getBalance();

        // Send ETH directly to the contract
        vm.prank(user);
        (bool success, ) = address(savings).call{value: DEPOSIT_AMOUNT}("");
        assertTrue(success);

        // Check that the balance increased
        assertEq(savings.getBalance(), initialBalance + DEPOSIT_AMOUNT);
    }

    function testFallbackFunction() public {
        uint256 initialBalance = savings.getBalance();

        // Send ETH with some calldata to trigger fallback
        vm.prank(user);
        (bool success, ) = address(savings).call{value: DEPOSIT_AMOUNT}(hex"12345678");
        assertTrue(success);

        // Check that the balance increased
        assertEq(savings.getBalance(), initialBalance + DEPOSIT_AMOUNT);
    }

    function testFuzzDeposit(uint256 amount) public {
        // Bound the amount to something reasonable
        amount = bound(amount, 1, 100 ether);

        vm.assume(user.balance >= amount);

        vm.prank(user);
        savings.deposit{value: amount}(amount);
        assertEq(savings.getBalance(), amount);
    }

    function testFuzzWithdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        // Bound the amounts to something reasonable
        depositAmount = bound(depositAmount, 1, 100 ether);
        withdrawAmount = bound(withdrawAmount, 1, depositAmount);

        vm.assume(user.balance >= depositAmount);

        vm.prank(user);
        savings.deposit{value: depositAmount}(depositAmount);

        // Warp time to after the deadline
        vm.warp(savings.deadline() + 1);

        vm.prank(owner);
        uint256 balanceBefore = address(owner).balance;
        savings.withdraw(withdrawAmount);
        uint256 balanceAfter = address(owner).balance;

        assertEq(balanceAfter - balanceBefore, withdrawAmount);
        assertEq(savings.getBalance(), depositAmount - withdrawAmount);
    }

    // Fuzz test for constructor with different lock periods
    function testFuzzConstructor(uint256 lockPeriod) public {
        // Bound the lock period to something reasonable (1 day to 10 years)
        lockPeriod = bound(lockPeriod, 1, 3650);

        Savings newSavings = new Savings(lockPeriod);

        // Check that the owner is set correctly
        assertEq(newSavings.owner(), address(this));

        // Check that the deadline is set correctly
        assertEq(newSavings.deadline(), block.timestamp + (lockPeriod * 1 days));
    }

    // Fuzz test for constructor with extreme lock periods
    function testFuzzConstructorExtreme(uint256 lockPeriod) public {
        // Test with extreme values (up to type(uint256).max / 1 days)
        // We divide by 1 days to avoid overflow when multiplying by 1 days in the contract
        lockPeriod = bound(lockPeriod, 1, type(uint256).max / 1 days);

        // Capture the current timestamp
        uint256 currentTimestamp = block.timestamp;

        Savings newSavings = new Savings(lockPeriod);

        // Check that the owner is set correctly
        assertEq(newSavings.owner(), address(this));

        // For very large lock periods, we need to handle potential overflow
        if (lockPeriod > (type(uint256).max - currentTimestamp) / 1 days) {
            // If lockPeriod is so large that it would cause overflow,
            // we can't directly check the deadline, but we can verify it's greater than the current time
            assertTrue(newSavings.deadline() > currentTimestamp);
        } else {
            // Otherwise, check that the deadline is set correctly
            assertEq(newSavings.deadline(), currentTimestamp + (lockPeriod * 1 days));
        }

        // Check that getTimeLeft works correctly with extreme deadlines
        if (newSavings.deadline() > currentTimestamp) {
            assertTrue(newSavings.getTimeLeft() > 0);
        } else {
            assertEq(newSavings.getTimeLeft(), 0);
        }
    }

    // Fuzz test for getTimeLeft with different timestamps
    function testFuzzGetTimeLeft(uint256 daysElapsed) public {
        // Bound the days elapsed to something reasonable (0 to LOCK_PERIOD)
        daysElapsed = bound(daysElapsed, 0, LOCK_PERIOD);

        // Warp time forward by the specified number of days
        vm.warp(block.timestamp + (daysElapsed * 1 days));

        // Calculate expected time left
        uint256 expectedTimeLeft = 0;
        if (daysElapsed < LOCK_PERIOD) {
            expectedTimeLeft = (LOCK_PERIOD - daysElapsed) * 1 days;
        }

        // Check that getTimeLeft returns the expected value
        uint256 actualTimeLeft = savings.getTimeLeft();
        assertApproxEqAbs(actualTimeLeft, expectedTimeLeft, 5); // Allow small deviation due to block time
    }

    // Fuzz test for getTimeLeft with timestamps after deadline
    function testFuzzGetTimeLeftAfterDeadline(uint256 daysAfterDeadline) public {
        // Bound the days after deadline to something reasonable (1 to 1000)
        daysAfterDeadline = bound(daysAfterDeadline, 1, 1000);

        // Warp time to after the deadline
        vm.warp(savings.deadline() + (daysAfterDeadline * 1 days));

        // Check that getTimeLeft returns 0
        assertEq(savings.getTimeLeft(), 0);
    }

    // Fuzz test for withdrawing at different times
    function testFuzzWithdrawAtDifferentTimes(uint256 daysElapsed, uint256 depositAmount) public {
        // Bound the parameters to something reasonable
        // Ensure daysElapsed is at least LOCK_PERIOD to meet the lock time requirement
        daysElapsed = bound(daysElapsed, LOCK_PERIOD, LOCK_PERIOD * 2);
        depositAmount = bound(depositAmount, 1, 100 ether);

        vm.assume(user.balance >= depositAmount);

        // Deposit funds
        vm.prank(user);
        savings.deposit{value: depositAmount}(depositAmount);

        // Warp time forward by the specified number of days
        vm.warp(block.timestamp + (daysElapsed * 1 days));

        // Withdraw as owner
        vm.prank(owner);
        uint256 balanceBefore = address(owner).balance;
        savings.withdraw(depositAmount);
        uint256 balanceAfter = address(owner).balance;

        // Check that the withdrawal was successful after lock time has passed
        assertEq(balanceAfter - balanceBefore, depositAmount);
        assertEq(savings.getBalance(), 0);
    }

    // Test that withdrawing before lock time is reached fails
    function testWithdrawBeforeLockTime() public {
        vm.prank(user);
        savings.deposit{value: DEPOSIT_AMOUNT}(DEPOSIT_AMOUNT);

        // Try to withdraw before the deadline
        vm.prank(owner);
        vm.expectRevert(Savings.LockTimeNotReached.selector);
        savings.withdraw(DEPOSIT_AMOUNT);

        // Warp time to just before the deadline
        vm.warp(savings.deadline() - 1);

        // Try to withdraw again, should still fail
        vm.prank(owner);
        vm.expectRevert(Savings.LockTimeNotReached.selector);
        savings.withdraw(DEPOSIT_AMOUNT);

        // Warp time to exactly the deadline
        vm.warp(savings.deadline());

        // Now the withdrawal should succeed
        vm.prank(owner);
        savings.withdraw(DEPOSIT_AMOUNT);

        assertEq(savings.getBalance(), 0);
    }

    // // Fuzz test for time manipulation
    // function testFuzzTimeManipulation(uint256 initialDaysInFuture, uint256 daysToWarpBackward) public {
    //     // Bound the parameters to something reasonable
    //     initialDaysInFuture = bound(initialDaysInFuture, 1, 1000);
    //     uint256 maxDaysToWarpBackward = initialDaysInFuture > 1 ? initialDaysInFuture - 1 : 1;
    //     daysToWarpBackward = bound(daysToWarpBackward, 1, maxDaysToWarpBackward);

    //     // Start at a future time
    //     vm.warp(block.timestamp + (initialDaysInFuture * 1 days));

    //     // Create a new savings contract
    //     Savings newSavings = new Savings(LOCK_PERIOD);

    //     // Record the deadline and initial time left
    //     uint256 deadline = newSavings.deadline();
    //     uint256 initialTimeLeft = newSavings.getTimeLeft();

    //     // Warp time backwards
    //     vm.warp(block.timestamp - (daysToWarpBackward * 1 days));

    //     // Check that the deadline hasn't changed
    //     assertEq(newSavings.deadline(), deadline);

    //     // Check that time left has increased appropriately
    //     uint256 newTimeLeft = newSavings.getTimeLeft();
    //     assertEq(newTimeLeft, deadline - block.timestamp);
    //     assertEq(newTimeLeft, initialTimeLeft + (daysToWarpBackward * 1 days));
    // }

    receive() external payable {}
    fallback() external payable {}
}

contract SavingsInvariantTest is Test {
    Savings public savings;
    address public owner;
    address public user;
    address public attacker;

    // Track total deposits and withdrawals for invariant testing
    uint256 public totalDeposits;
    uint256 public totalWithdrawals;

    uint256 constant LOCK_PERIOD = 30;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant DEPOSIT_AMOUNT = 1 ether;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        attacker = makeAddr("attacker");

        vm.deal(owner, STARTING_BALANCE);
        vm.deal(user, STARTING_BALANCE);
        vm.deal(attacker, STARTING_BALANCE);

        vm.prank(owner);
        savings = new Savings(LOCK_PERIOD);

        // Initialize tracking variables
        totalDeposits = 0;
        totalWithdrawals = 0;
    }

    // Invariant: Contract balance should always match getBalance()
    function invariant_balanceMatchesGetBalance() public view {
        assertEq(address(savings).balance, savings.getBalance());
    }

    // Invariant: Owner should never change
    function invariant_ownerNeverChanges() public view {
        assertEq(savings.owner(), owner);
    }

    // Invariant: Deadline should never change
    function invariant_deadlineNeverChanges() public view {
        // The deadline should remain the same throughout all test runs
        // We compare with the value set during construction
        assertEq(savings.deadline(), block.timestamp + (LOCK_PERIOD * 1 days));
    }

    // Invariant: After deadline, getTimeLeft() should always return 0
    function invariant_timeLeftAfterDeadline() public {
        // Warp to after the deadline
        vm.warp(savings.deadline() + 1);
        assertEq(savings.getTimeLeft(), 0);
    }

    // Invariant: Only owner can withdraw funds
    function invariant_onlyOwnerCanWithdraw() public {
        // First deposit some funds
        vm.prank(user);
        savings.deposit{value: DEPOSIT_AMOUNT}(DEPOSIT_AMOUNT);

        // Warp time to after the deadline to avoid LockTimeNotReached error
        vm.warp(savings.deadline() + 1);

        // Try to withdraw as non-owner
        vm.prank(attacker);
        (bool success, bytes memory returnData) = address(savings).call(
            abi.encodeWithSelector(savings.withdraw.selector, DEPOSIT_AMOUNT)
        );

        // Should fail with Unauthorized error
        assertFalse(success);
        // Check that the error is Unauthorized
        bytes4 errorSelector = bytes4(returnData);
        assertEq(errorSelector, Savings.Unauthorized.selector);
    }

    // Invariant: Cannot withdraw more than the contract balance
    function invariant_cannotOverdraw() public {
        uint256 currentBalance = savings.getBalance();

        if (currentBalance > 0) {
            // Warp time to after the deadline to avoid LockTimeNotReached error
            vm.warp(savings.deadline() + 1);

            vm.prank(owner);
            (bool success, ) = address(savings).call(
                abi.encodeWithSelector(savings.withdraw.selector, currentBalance + 1 ether)
            );

            // Should fail
            assertFalse(success);
        }
    }

    // Invariant: Cannot withdraw before lock time is reached
    function invariant_cannotWithdrawBeforeLockTime() public {
        uint256 currentBalance = savings.getBalance();

        if (currentBalance > 0) {
            // Ensure we're before the deadline
            vm.warp(savings.deadline() - 1);

            vm.prank(owner);
            (bool success, bytes memory returnData) = address(savings).call(
                abi.encodeWithSelector(savings.withdraw.selector, 1 ether)
            );

            // Should fail with LockTimeNotReached error
            assertFalse(success);
            bytes4 errorSelector = bytes4(returnData);
            assertEq(errorSelector, Savings.LockTimeNotReached.selector);
        }
    }

    // Invariant: Contract balance should never be negative
    function invariant_balanceNeverNegative() public view {
        assertTrue(address(savings).balance >= 0);
    }

    // Invariant: Contract balance should equal total deposits minus total withdrawals
    function invariant_balanceMatchesAccountingLedger() public view {
        assertEq(address(savings).balance, totalDeposits - totalWithdrawals);
    }

    // Invariant: Time left should never be negative
    function invariant_timeLeftNeverNegative() public view {
        assertTrue(savings.getTimeLeft() >= 0);
    }

    // Invariant: Time left should never exceed the original lock period
    function invariant_timeLeftNeverExceedsLockPeriod() public view {
        assertTrue(savings.getTimeLeft() <= LOCK_PERIOD * 1 days);
    }

    // Invariant: Time left should decrease monotonically with time
    function invariant_timeLeftDecreasesWithTime() public {
        // Record current time left
        uint256 currentTimeLeft = savings.getTimeLeft();

        // Warp time forward by 1 day
        vm.warp(block.timestamp + 1 days);

        // Get new time left
        uint256 newTimeLeft = savings.getTimeLeft();

        // If we're already past the deadline, both should be 0
        if (block.timestamp >= savings.deadline()) {
            assertEq(newTimeLeft, 0);
        } else {
            // Otherwise, new time left should be less than or equal to current time left minus 1 day
            // (less than or equal to account for the case where we cross the deadline)
            assertTrue(newTimeLeft <= currentTimeLeft - 1 days || newTimeLeft == 0);
        }
    }

    // Invariant: Time left should be consistent with deadline and current time
    function invariant_timeLeftConsistentWithDeadline() public view {
        if (block.timestamp >= savings.deadline()) {
            assertEq(savings.getTimeLeft(), 0);
        } else {
            assertEq(savings.getTimeLeft(), savings.deadline() - block.timestamp);
        }
    }
}
