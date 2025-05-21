// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

// A time-locked vault
contract Savings {
    error Unauthorized();
    error InvalidAmount();
    error TransferUnsuccessful(uint256);
    error LockTimeNotReached();

    address public owner;
    uint256 public deadline;

    modifier onlyOwner() {
        require(msg.sender == owner, Unauthorized());
        _;
    }

    // @dev `now` was deprecated in 0.7.0
    // Use `block.timestamp` instead.
    constructor(uint256 numberOfDays) {
        owner = msg.sender;
        deadline = block.timestamp + (numberOfDays * 1 days);
    }

    function deposit(uint256 _amount) payable external {
        require(msg.value == _amount, InvalidAmount());
    }

    function withdraw(uint256 _amount) external onlyOwner {
        require(block.timestamp >= deadline, LockTimeNotReached());

        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, TransferUnsuccessful(_amount));
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getTimeLeft() external view returns (uint256) {
        if (block.timestamp >= deadline) {
            return 0;
        }
        return deadline - block.timestamp;
    }

    receive() external payable {}
    fallback() external payable {}
}
