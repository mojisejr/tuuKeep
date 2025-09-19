// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title SimpleToken
 * @dev Basic ERC20 token to test KUB testnet deployment
 */
contract SimpleToken is ERC20 {
    address public immutable admin;

    constructor(address _admin) ERC20("Simple Token", "SIMPLE") {
        require(_admin != address(0), "SimpleToken: admin cannot be zero address");
        admin = _admin;
        _mint(_admin, 1000000 * 10**18); // 1M tokens
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == admin, "SimpleToken: only admin can mint");
        _mint(to, amount);
    }
}