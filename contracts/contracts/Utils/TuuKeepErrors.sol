// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title TuuKeepErrors
 * @dev Custom errors for gas-efficient error handling
 */
library TuuKeepErrors {
    // Access control errors
    error Unauthorized();
    error InvalidRole();

    // Cabinet errors
    error CabinetNotFound();
    error CabinetInactive();
    error CabinetExists();
    error InvalidPrice();
    error InvalidStatus();

    // Asset errors
    error AssetNotFound();
    error InvalidAsset();
    error AssetExists();
    error MaxItemsExceeded();
    error InvalidRarity();
    error TransferFailed();

    // Play errors
    error InsufficientPayment();
    error NoItemsAvailable();
    error PlayFailed();
    error InvalidOddsBoost();

    // General errors
    error InvalidAddress();
    error InvalidAmount();
    error InvalidIndex();
    error ContractPaused();
    error ReentrantCall();

    // Marketplace specific errors
    error InvalidFeeRate(uint256 rate);
    error InvalidConfiguration(string configType, string reason);
}