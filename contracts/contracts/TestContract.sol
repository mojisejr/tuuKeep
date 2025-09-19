// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title TestContract
 * @dev Minimal contract to test KUB testnet deployment
 */
contract TestContract {
    string public name;
    address public owner;
    uint256 public value;

    event ValueSet(uint256 newValue, address indexed setter);

    constructor(string memory _name) {
        name = _name;
        owner = msg.sender;
        value = 42;
    }

    function setValue(uint256 _value) external {
        value = _value;
        emit ValueSet(_value, msg.sender);
    }

    function getName() external view returns (string memory) {
        return name;
    }

    function getOwner() external view returns (address) {
        return owner;
    }
}