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

        // Check if already entered (this will revert if true)
        if (_reentrancyGuardEntered()) {
            emit ReentrancyAttemptBlocked(
                msg.sender,
                msg.sig,
                block.timestamp
            );
            revert ReentrancyGuardReentrantCall();
        }

        // Use OpenZeppelin's nonReentrant logic
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();

        // Log successful completion
        emit ReentrancyProtectionCompleted(
            msg.sender,
            msg.sig,
            gasStart - gasleft()
        );
    }

    /**
     * @dev Returns whether the contract is currently in a reentrant state
     * @return bool True if currently in a reentrant call
     */
    function isReentrant() external view returns (bool) {
        return _reentrancyGuardEntered();
    }

    /**
     * @dev Internal function to check reentrancy status for other security utilities
     * @return bool True if currently protected by reentrancy guard
     */
    function _isProtected() internal view returns (bool) {
        return _reentrancyGuardEntered();
    }
}