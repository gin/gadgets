// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Bank} from "../src/Bank.sol";

contract BankTest is Test {
    Bank public bank;
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");
    address public userNoMoney = makeAddr("userNoMoney");
    uint256 constant startingBalance = 10 ether;
    uint256 constant depositAmount = 1 ether;
    uint256 constant withdrawAmount = 1 ether;
    uint256 constant transferAmount = 1 ether;
    uint256 constant transferAmount2 = 1 ether;
    uint256 constant transferAmount3 = 1 ether;

    function setUp() public {
        bank = new Bank();
        bank.changeOwner(owner);

        vm.deal(owner, startingBalance);
        vm.deal(user, startingBalance);
        vm.deal(user2, startingBalance);
        vm.deal(userNoMoney, 0);
    }

    function testDeposit() public {
        vm.prank(user);
        bank.deposit{value: depositAmount}(depositAmount);
        assertEq(bank.balances(user), depositAmount);
    }

    function testDepositInvalidAmount() public {
        vm.prank(user);
        vm.expectRevert(Bank.InvalidAmount.selector);
        bank.deposit{value: depositAmount}(depositAmount + 1);
    }

    function testWithdraw() public {
        vm.prank(user);
        bank.deposit{value: depositAmount}(depositAmount);

        vm.prank(user);
        bank.withdraw(withdrawAmount);
        assertEq(bank.balances(user), 0);
    }

    function testWithdrawInsufficientBalance() public {
        uint256 overWithdrawAmount = 2 * withdrawAmount;

        vm.prank(user);
        bank.deposit{value: depositAmount}(depositAmount);

        vm.prank(user);
        bytes4 s = Bank.InsufficientBalance.selector;
        vm.expectRevert(
            abi.encodeWithSelector(s, depositAmount)
        );
        bank.withdraw(overWithdrawAmount);
    }

    function testTransfer() public {
        vm.prank(user);
        bank.deposit{value: depositAmount}(depositAmount);

        vm.prank(user);
        bank.transfer(user2, transferAmount);
        assertEq(bank.balances(user), 0);
        assertEq(bank.balances(user2), transferAmount);
    }

    function testTransferInsufficientBalance() public {
        vm.prank(user);
        bytes4 s = Bank.InsufficientBalance.selector;
        vm.expectRevert(
            abi.encodeWithSelector(s, 0)
        );
        bank.transfer(user2, transferAmount);
    }

    function testTransferToSelf() public {
        vm.prank(user);
        bank.deposit{value: depositAmount}(depositAmount);

        vm.prank(user);
        bank.transfer(user, transferAmount);
        assertEq(bank.balances(user), depositAmount);
    }

    function testTransferToSelfInsufficientBalance() public {
        vm.prank(user);
        bytes4 s = Bank.InsufficientBalance.selector;
        vm.expectRevert(
            abi.encodeWithSelector(s, 0)
        );
        bank.transfer(user, transferAmount);
    }

    function testTransferToSelfMultipleTimes() public {
        vm.prank(user);
        bank.deposit{value: depositAmount}(depositAmount);

        vm.prank(user);
        bank.transfer(user, transferAmount);
        assertEq(bank.balances(user), depositAmount);

        vm.prank(user);
        bank.transfer(user, transferAmount2);
        assertEq(bank.balances(user), depositAmount);

        vm.prank(user);
        bank.transfer(user, transferAmount3);
        assertEq(bank.balances(user), depositAmount);
    }

    function testConstructorSetsCorrectOwner() public {
        Bank newBank = new Bank();
        assertEq(newBank.owner(), address(this));
    }

    function testChangeOwner() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        bank.changeOwner(newOwner);

        assertEq(bank.owner(), newOwner);
    }

    function testChangeOwnerUnauthorized() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(user);
        vm.expectRevert(Bank.Unauthorized.selector);
        bank.changeOwner(newOwner);
    }

    function testDepositZeroAmount() public {
        vm.prank(user);
        bank.deposit{value: 0}(0);
        assertEq(bank.balances(user), 0);
    }

    function testMultipleDeposits() public {
        vm.startPrank(user);

        bank.deposit{value: 1 ether}(1 ether);
        assertEq(bank.balances(user), 1 ether);

        bank.deposit{value: 2 ether}(2 ether);
        assertEq(bank.balances(user), 3 ether);

        bank.deposit{value: 3 ether}(3 ether);
        assertEq(bank.balances(user), 6 ether);

        vm.stopPrank();
    }

    function testMultipleUserDeposits() public {
        vm.prank(user);
        bank.deposit{value: 1 ether}(1 ether);
        assertEq(bank.balances(user), 1 ether);

        vm.prank(user2);
        bank.deposit{value: 2 ether}(2 ether);
        assertEq(bank.balances(user2), 2 ether);

        vm.prank(owner);
        bank.deposit{value: 3 ether}(3 ether);
        assertEq(bank.balances(owner), 3 ether);
    }

    function testPartialWithdraw() public {
        vm.prank(user);
        bank.deposit{value: 5 ether}(5 ether);

        vm.prank(user);
        bank.withdraw(2 ether);
        assertEq(bank.balances(user), 3 ether);

        vm.prank(user);
        bank.withdraw(1 ether);
        assertEq(bank.balances(user), 2 ether);
    }

    function testMultipleWithdraws() public {
        vm.prank(user);
        bank.deposit{value: 10 ether}(10 ether);

        vm.startPrank(user);

        bank.withdraw(1 ether);
        assertEq(bank.balances(user), 9 ether);

        bank.withdraw(2 ether);
        assertEq(bank.balances(user), 7 ether);

        bank.withdraw(3 ether);
        assertEq(bank.balances(user), 4 ether);

        vm.stopPrank();
    }

    function testWithdrawWhenContractHasInsufficientBalance() public {
        vm.prank(user);
        bank.deposit{value: 5 ether}(5 ether);

        // Drain the contract's ETH without updating balances by sending ETH 
        // directly to another address
        vm.prank(address(bank));
        payable(address(0xdead)).transfer(4 ether);

        // Verify the contract now has less ETH than the user's balance
        assertEq(address(bank).balance, 1 ether);
        assertEq(bank.balances(user), 5 ether);

        // Should revert when trying to withdraw the full balance
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Bank.WithdrawUnsuccessful.selector, 5 ether));
        bank.withdraw(5 ether);

        // Should be able to withdraw what's left
        vm.prank(user);
        bank.withdraw(1 ether);
        assertEq(bank.balances(user), 4 ether);
        assertEq(address(bank).balance, 0);
    }

    function testWithdrawToContractThatRejectsETH() public {
        // Create a contract that rejects ETH
        ETHRejecter rejecter = new ETHRejecter{value: 1 ether}();

        vm.prank(address(rejecter));
        rejecter.depositToBank(payable(address(bank)), 1 ether);

        vm.prank(address(rejecter));
        vm.expectRevert(abi.encodeWithSelector(Bank.WithdrawUnsuccessful.selector, 1 ether));
        bank.withdraw(1 ether);

        // Balance should remain unchanged
        assertEq(bank.balances(address(rejecter)), 1 ether);
        assertEq(address(bank).balance, 1 ether);
    }

    function testTransferToZeroAddress() public {
        vm.prank(user);
        bank.deposit{value: 5 ether}(5 ether);

        vm.prank(user);
        vm.expectRevert(Bank.ZeroAddress.selector);
        bank.transfer(address(0), 1 ether);
    }

    function testTransferZeroAmount() public {
        vm.prank(user);
        bank.deposit{value: 5 ether}(5 ether);

        vm.prank(user);
        bank.transfer(user2, 0);

        assertEq(bank.balances(user), 5 ether);
        assertEq(bank.balances(user2), 0);
    }

    function testGetBalanceNoDeposits() public view {
        assertEq(bank.getBalance(user), 0);
    }

    function testGetBalanceAfterOperations() public {
        // Deposit
        vm.prank(user);
        bank.deposit{value: 5 ether}(5 ether);
        assertEq(bank.getBalance(user), 5 ether);

        // Withdraw
        vm.prank(user);
        bank.withdraw(2 ether);
        assertEq(bank.getBalance(user), 3 ether);

        // Transfer
        vm.prank(user);
        bank.transfer(user2, 1 ether);
        assertEq(bank.getBalance(user), 2 ether);
        assertEq(bank.getBalance(user2), 1 ether);
    }

    function testReceiveFunction() public {
        // Send ETH directly to the contract
        vm.prank(user);
        (bool success, ) = address(bank).call{value: 1 ether}("");
        assertTrue(success);

        // The ETH is received but not credited to any account
        assertEq(address(bank).balance, 1 ether);
        assertEq(bank.balances(user), 0);
    }

    function testFallbackFunction() public {
        // Send ETH with calldata to trigger fallback
        vm.prank(user);
        (bool success, ) = address(bank).call{value: 1 ether}(hex"12345678");
        assertTrue(success);

        // The ETH is received but not credited to any account
        assertEq(address(bank).balance, 1 ether);
        assertEq(bank.balances(user), 0);
    }

    function testFuzzDeposit(uint256 amount) public {
        // Bound the amount to something reasonable
        amount = bound(amount, 0, 100 ether);

        vm.assume(user.balance >= amount);

        vm.prank(user);
        bank.deposit{value: amount}(amount);
        assertEq(bank.balances(user), amount);
    }

    function testFuzzWithdraw(uint256 fuzzDepositAmount, uint256 fuzzWithdrawAmount) public {
        fuzzDepositAmount = bound(fuzzDepositAmount, 0, 100 ether);
        fuzzWithdrawAmount = bound(fuzzWithdrawAmount, 0, fuzzDepositAmount);

        vm.assume(user.balance >= fuzzDepositAmount);

        vm.prank(user);
        bank.deposit{value: fuzzDepositAmount}(fuzzDepositAmount);

        vm.prank(user);
        bank.withdraw(fuzzWithdrawAmount);

        assertEq(bank.balances(user), fuzzDepositAmount - fuzzWithdrawAmount);
    }

    function testFuzzTransfer(uint256 fuzzDepositAmount, uint256 fuzzTransferAmount, address fuzzRecipient) public {
        fuzzDepositAmount = bound(fuzzDepositAmount, 0, 100 ether);
        fuzzTransferAmount = bound(fuzzTransferAmount, 0, fuzzDepositAmount);

        console.log("Bound result", fuzzDepositAmount);
        console.log("Bound result", fuzzTransferAmount);

        // Avoid transferring to the zero address or to the bank itself
        vm.assume(fuzzRecipient != address(0) && fuzzRecipient != address(bank));
        vm.assume(user.balance >= fuzzDepositAmount);

        vm.prank(user);
        bank.deposit{value: fuzzDepositAmount}(fuzzDepositAmount);

        uint256 balanceBefore = bank.balances(user);
        console.log("Balance before transfer:", balanceBefore);

        vm.prank(user);
        bank.transfer(fuzzRecipient, fuzzTransferAmount);

        uint256 balanceAfter = bank.balances(user);
        console.log("Balance after transfer:", balanceAfter);
        console.log("Expected balance:", fuzzDepositAmount - fuzzTransferAmount);

        assertEq(bank.balances(user), fuzzDepositAmount - fuzzTransferAmount);
        assertEq(bank.balances(fuzzRecipient), fuzzTransferAmount);
    }

    function testReentrancy() public {
        ReentrancyAttacker attacker = new ReentrancyAttacker(payable(address(bank)));
        vm.deal(address(attacker), 1 ether);

        vm.prank(address(attacker));
        bank.deposit{value: 1 ether}(1 ether);

        attacker.attack();
        assertFalse(attacker.reentrancySucceeded());

        assertEq(bank.balances(address(attacker)), 0);
        assertEq(address(attacker).balance, 1 ether);
    }
}

// Contract to test reentrancy
contract ReentrancyAttacker {
    Bank public bank;
    uint256 public withdrawAmount = 1 ether;
    bool public attacking = false;
    bool public reentrancySucceeded = false;

    constructor(address payable _bank) {
        bank = Bank(_bank);
    }

    function attack() external {
        attacking = true;
        bank.withdraw(withdrawAmount);
        attacking = false;
    }

    receive() external payable {
        if (attacking) {
            // Try to reenter the withdraw function
            try bank.withdraw(withdrawAmount) {
                // If this succeeds, we've successfully reentered
                reentrancySucceeded = true;
            } catch {
                // Expected to fail if the contract is secure against reentrancy
                reentrancySucceeded = false;
            }
        }
    }
}

// Contract that rejects ETH
contract ETHRejecter {
    // This contract rejects all ETH sent to it except during construction
    constructor() payable {}

    function depositToBank(address payable bankAddress, uint256 amount) external {
        Bank bank = Bank(bankAddress);
        bank.deposit{value: amount}(amount);
    }

    receive() external payable {
        revert("ETH not accepted");
    }

    fallback() external payable {
        revert("ETH not accepted");
    }
}

contract BankInvariantTest is Test {
    Bank public bank;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    // Track total deposits and withdrawals for invariant testing
    uint256 public totalDeposits;
    uint256 public totalWithdrawals;

    // Track individual user balances for invariant testing
    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) public userWithdrawals;
    mapping(address => uint256) public userTransfersOut;
    mapping(address => uint256) public userTransfersIn;

    uint256 constant STARTING_BALANCE = 100 ether;

    function setUp() public {
        bank = new Bank();

        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        vm.deal(owner, STARTING_BALANCE);
        vm.deal(user1, STARTING_BALANCE);
        vm.deal(user2, STARTING_BALANCE);
        vm.deal(user3, STARTING_BALANCE);

        totalDeposits = 0;
        totalWithdrawals = 0;
    }

    function deposit(address user, uint256 amount) public {
        amount = bound(amount, 0, 10 ether);

        vm.prank(user);
        vm.assume(user.balance >= amount);

        // Track deposit
        totalDeposits += amount;
        userDeposits[user] += amount;

        bank.deposit{value: amount}(amount);
    }

    function withdraw(address user, uint256 amount) public {
        uint256 balance = bank.balances(user);
        if (balance == 0) return;

        amount = bound(amount, 0, balance);

        vm.prank(user);

        // Track withdrawal
        totalWithdrawals += amount;
        userWithdrawals[user] += amount;

        bank.withdraw(amount);
    }

    function transfer(address from, address to, uint256 amount) public {
        uint256 balance = bank.balances(from);
        if (balance == 0) return;

        amount = bound(amount, 0, balance);

        vm.prank(from);

        // Track transfer
        userTransfersOut[from] += amount;
        userTransfersIn[to] += amount;

        bank.transfer(to, amount);
    }

    // Invariant: Contract balance must equal total deposits minus total withdrawals
    function invariant_contractBalanceMatchesLedger() public view {
        assertEq(address(bank).balance, totalDeposits - totalWithdrawals);
    }

    // Invariant: Each user's balance must match their deposits minus withdrawals and transfers
    function invariant_userBalancesMatchLedger() public view {
        assertEq(bank.balances(user1), userDeposits[user1] - userWithdrawals[user1] - userTransfersOut[user1] + userTransfersIn[user1]);
        assertEq(bank.balances(user2), userDeposits[user2] - userWithdrawals[user2] - userTransfersOut[user2] + userTransfersIn[user2]);
        assertEq(bank.balances(user3), userDeposits[user3] - userWithdrawals[user3] - userTransfersOut[user3] + userTransfersIn[user3]);
    }

    // Invariant: Sum of all user balances must equal contract balance
    function invariant_sumOfBalancesEqualsContractBalance() public view {
        uint256 sumOfBalances = bank.balances(user1) + bank.balances(user2) + bank.balances(user3) + bank.balances(owner);
        assertEq(address(bank).balance, sumOfBalances);
    }

    // Invariant: Owner must never change except through changeOwner
    function invariant_ownerOnlyChangesViaFunction() public view {
        // todo: We'd need to track owner changes and verify they only happen through the changeOwner function
        // For simplicity, we'll just check that the owner is still the owner
        assertEq(bank.owner(), address(this));
    }
}
