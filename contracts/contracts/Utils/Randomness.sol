// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Randomness
 * @dev Provides secure on-chain pseudo-randomness for gacha mechanics
 * @notice This contract generates random numbers using multiple entropy sources
 * to provide manipulation-resistant randomness for gaming applications
 */
contract Randomness is AccessControl {
    bytes32 public constant CONSUMER_ROLE = keccak256("CONSUMER_ROLE");

    uint256 private _nonce;

    event RandomNumberGenerated(
        address indexed requester,
        uint256 indexed requestId,
        uint256 randomNumber,
        uint256 blockNumber
    );

    event ConsumerAdded(address indexed consumer);
    event ConsumerRemoved(address indexed consumer);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _nonce = 0;
    }

    /**
     * @dev Add a consumer contract that can request random numbers
     * @param consumer Address of the consumer contract
     */
    function addConsumer(address consumer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(consumer != address(0), "Invalid consumer address");
        _grantRole(CONSUMER_ROLE, consumer);
        emit ConsumerAdded(consumer);
    }

    /**
     * @dev Remove a consumer contract
     * @param consumer Address of the consumer contract to remove
     */
    function removeConsumer(address consumer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(CONSUMER_ROLE, consumer);
        emit ConsumerRemoved(consumer);
    }

    /**
     * @dev Generate a random number using multiple entropy sources
     * @param requestId Unique identifier for this randomness request
     * @return Random number between 1 and type(uint256).max
     */
    function generateRandomNumber(uint256 requestId) external onlyRole(CONSUMER_ROLE) returns (uint256) {
        require(requestId > 0, "Request ID must be greater than zero");

        // Increment nonce for additional entropy
        _nonce++;

        // Combine multiple entropy sources
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(
            block.prevrandao,     // Validator randomness (EIP-4399)
            block.timestamp,      // Current block timestamp
            block.number,         // Current block number
            msg.sender,           // Calling contract address
            requestId,            // Request identifier
            _nonce               // Internal counter
        )));

        // Ensure we never return 0
        uint256 randomNumber = randomSeed == 0 ? 1 : randomSeed;

        emit RandomNumberGenerated(msg.sender, requestId, randomNumber, block.number);

        return randomNumber;
    }

    /**
     * @dev Generate a random number within a specific range
     * @param requestId Unique identifier for this randomness request
     * @param min Minimum value (inclusive)
     * @param max Maximum value (inclusive)
     * @return Random number between min and max (inclusive)
     */
    function generateRandomInRange(
        uint256 requestId,
        uint256 min,
        uint256 max
    ) external onlyRole(CONSUMER_ROLE) returns (uint256) {
        require(min <= max, "Invalid range: min must be <= max");
        require(requestId > 0, "Request ID must be greater than zero");

        if (min == max) {
            return min;
        }

        uint256 randomNumber = this.generateRandomNumber(requestId);
        uint256 range = max - min + 1;

        return min + (randomNumber % range);
    }

    /**
     * @dev Get the current nonce value
     * @return Current nonce value
     */
    function getCurrentNonce() external view returns (uint256) {
        return _nonce;
    }

    /**
     * @dev Check if an address has consumer role
     * @param account Address to check
     * @return True if address has consumer role
     */
    function isConsumer(address account) external view returns (bool) {
        return hasRole(CONSUMER_ROLE, account);
    }
}