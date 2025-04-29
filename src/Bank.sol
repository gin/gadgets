// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

contract Bank {
    error Unauthorized();
    error ZeroAddress();
    error WithdrawUnsuccessful(uint256);
    error InvalidAmount();
    error InsufficientBalance(uint256);

    mapping(address => uint256) public balances;
    address public owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function changeOwner(address _newOwner) external onlyOwner {
        owner = _newOwner;
    }

    function deposit(uint256 _amount) payable external {
        if (msg.value != _amount) revert InvalidAmount();
        balances[msg.sender] += _amount;
    }

    function withdraw(uint256 _amount) external {
        if (balances[msg.sender] < _amount) revert InsufficientBalance(balances[msg.sender]);
        balances[msg.sender] -= _amount;
        (bool success, ) = msg.sender.call{value: _amount}("");
        if (!success) revert WithdrawUnsuccessful(_amount);
    }

    function transfer(address _to, uint256 _amount) external {
        if (balances[msg.sender] < _amount) revert InsufficientBalance(balances[msg.sender]);
        if (_to == address(0)) revert ZeroAddress();
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
    }

    function getBalance(address _user) external view returns (uint256) {
        return balances[_user];
    }

    receive() external payable {}
    fallback() external payable {}
}
