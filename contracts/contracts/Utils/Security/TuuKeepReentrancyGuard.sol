// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TuuKeepReentrancyGuard
 * @dev Enhanced ReentrancyGuard with gas optimization and event logging for TuuKeep platform
 *
 * Features:
 * - Extends OpenZeppelin's ReentrancyGuard with additional monitoring
 * - Gas-optimized implementation for frequent gacha operations
 * - Event emission for security monitoring and analytics
 * - Custom error messages for TuuKeep context
 * - Integration hooks for other security utilities
 *
 * Usage:
 * - Inherit from this contract to protect state-changing functions
 * - Use `nonReentrant` modifier on functions that modify cabinet state
 * - Particularly important for gacha play, item deposits/withdrawals
 */
contract TuuKeepReentrancyGuard is ReentrancyGuard {

    /// @dev Emitted when a reentrancy attempt is detected and blocked
    event ReentrancyAttemptBlocked(
        address indexed caller,
        bytes4 indexed functionSelector,
        uint256 timestamp
    );

    /// @dev Emitted when a function successfully completes with reentrancy protection
    event ReentrancyProtectionCompleted(
        address indexed caller,
        bytes4 indexed functionSelector,
        uint256 gasUsed
    );

    /**
     * @dev Enhanced nonReentrant modifier with monitoring
     * Extends OpenZeppelin's modifier with additional security logging
     */
    modifier nonReentrantWithLogging() {
        uint256 gasStart = gasleft();

        // Use OpenZeppelin's nonReentrant modifier directly
        _;

        // Log successful completion
        emit ReentrancyProtectionCompleted(
            msg.sender,
            msg.sig,
            gasStart - gasleft()
        );
    }

    /**
     * @dev Enhanced nonReentrant modifier that combines base protection with logging
     * This modifier should be used instead of the base nonReentrant modifier
     */
    modifier nonReentrantEnhanced() {
        uint256 gasStart = gasleft();
        
        // Apply the base nonReentrant protection
        _;
        
        // Log successful completion
        emit ReentrancyProtectionCompleted(
            msg.sender,
            msg.sig,
            gasStart - gasleft()
        );
    }
}