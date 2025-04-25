// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

contract CommunityChest {
    error InvalidAmount();
    error TransferUnsuccessful(uint256);

    function deposit(uint256 _amount) payable external {
        if (msg.value != _amount) revert InvalidAmount();
    }

    // Community chest. Anyone can withdraw, so no onlyOwner modifier here.
    function withdraw(uint256 _amount) external {
        (bool success, ) = msg.sender.call{value: _amount}("");
        if (!success) revert TransferUnsuccessful(_amount);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {}
    fallback() external payable {}
}
