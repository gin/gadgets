// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

contract TipJar {
    error InvalidAmount();
    error TransferUnsuccessful(uint256);
    error Unauthorized();
    error WithdrawUnsuccessful(uint256);
    error ZeroAddress();

    address public owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function changeOwner(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        owner = _newOwner;
    }

    function deposit(uint256 _amount) payable external {
        if (msg.value != _amount) revert InvalidAmount();
    }

    function withdraw(uint256 _amount) external onlyOwner {
        (bool success, ) = msg.sender.call{value: _amount}("");
        if (!success) revert WithdrawUnsuccessful(_amount);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {}
    fallback() external payable {}
}
