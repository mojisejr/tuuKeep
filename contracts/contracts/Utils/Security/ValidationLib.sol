// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title ValidationLib
 * @dev Comprehensive input validation utilities for TuuKeep platform
 *
 * Features:
 * - Custom error types for gas efficiency
 * - Platform-specific validation rules for cabinet and marketplace operations
 * - Ownership verification utilities for NFT operations
 * - String and array validation with gas optimization
 * - Integration with cabinet and marketplace logic
 * - Price and amount validation with bounds checking
 *
 * Usage:
 * - Use for all parameter validation across TuuKeep contracts
 * - Particularly important for cabinet configuration and marketplace listings
 * - User input validation in frontend interactions
 * - Security boundary enforcement
 */
library ValidationLib {
    using Address for address;

    /// @dev Custom errors for gas efficiency
    error InvalidAddress(address provided, string reason);
    error InvalidAmount(uint256 provided, uint256 min, uint256 max, string context);
    error InvalidArrayLength(uint256 provided, uint256 min, uint256 max, string context);
    error InvalidString(string provided, string reason);
    error OwnershipValidationFailed(address token, address owner, uint256 tokenId);
    error BalanceValidationFailed(address token, address account, uint256 required);
    error InvalidConfiguration(string parameter, string reason);

    /// @dev Constants for validation limits
    uint256 public constant MAX_CABINET_ITEMS = 10;
    uint256 public constant MIN_PLAY_PRICE = 1e15; // 0.001 ETH equivalent
    uint256 public constant MAX_PLAY_PRICE = 1e20; // 100 ETH equivalent
    uint256 public constant MAX_STRING_LENGTH = 256;
    uint256 public constant MIN_STRING_LENGTH = 1;

    /**
     * @dev Validate an Ethereum address with context
     * @param addr The address to validate
     * @param context Description of what the address represents
     */
    function validateAddress(address addr, string memory context) internal pure {
        if (addr == address(0)) {
            revert InvalidAddress(addr, string(abi.encodePacked("Zero address not allowed for ", context)));
        }
    }

    /**
     * @dev Validate contract address (must have code)
     * @param addr The address to validate
     * @param context Description of what the contract represents
     */
    function validateContract(address addr, string memory context) internal view {
        validateAddress(addr, context);
        if (!_isContract(addr)) {
            revert InvalidAddress(addr, string(abi.encodePacked("Address must be a contract for ", context)));
        }
    }

    /**
     * @dev Check if an address is a contract
     * @param addr The address to check
     * @return true if the address is a contract, false otherwise
     */
    function _isContract(address addr) private view returns (bool) {
        return addr.code.length > 0;
    }

    /**
     * @dev Validate amount within specified bounds
     * @param amount The amount to validate
     * @param min Minimum allowed value (inclusive)
     * @param max Maximum allowed value (inclusive)
     * @param context Description of what the amount represents
     */
    function validateAmount(
        uint256 amount,
        uint256 min,
        uint256 max,
        string memory context
    ) internal pure {
        if (amount < min || amount > max) {
            revert InvalidAmount(amount, min, max, context);
        }
    }

    /**
     * @dev Validate play price for cabinet operations
     * @param price The price to validate
     */
    function validatePlayPrice(uint256 price) internal pure {
        validateAmount(price, MIN_PLAY_PRICE, MAX_PLAY_PRICE, "cabinet play price");
    }

    /**
     * @dev Validate TuuCoin burn amount (max 20% of play price)
     * @param burnAmount The amount of TuuCoin to burn
     * @param playPrice The cabinet play price
     */
    function validateBurnAmount(uint256 burnAmount, uint256 playPrice) internal pure {
        uint256 maxBurn = (playPrice * 20) / 100; // 20% of play price
        validateAmount(burnAmount, 0, maxBurn, "TuuCoin burn amount");
    }

    /**
     * @dev Validate array length within bounds
     * @param length The array length to validate
     * @param min Minimum allowed length (inclusive)
     * @param max Maximum allowed length (inclusive)
     * @param context Description of what the array contains
     */
    function validateArrayLength(
        uint256 length,
        uint256 min,
        uint256 max,
        string memory context
    ) internal pure {
        if (length < min || length > max) {
            revert InvalidArrayLength(length, min, max, context);
        }
    }

    /**
     * @dev Validate cabinet items array (max 10 items)
     * @param itemCount The number of items to validate
     */
    function validateCabinetItems(uint256 itemCount) internal pure {
        validateArrayLength(itemCount, 1, MAX_CABINET_ITEMS, "cabinet items");
    }

    /**
     * @dev Validate non-empty string within length limits
     * @param str The string to validate
     * @param context Description of what the string represents
     */
    function validateNonEmptyString(string memory str, string memory context) internal pure {
        bytes memory strBytes = bytes(str);
        if (strBytes.length == 0) {
            revert InvalidString(str, string(abi.encodePacked("Empty string not allowed for ", context)));
        }
        if (strBytes.length > MAX_STRING_LENGTH) {
            revert InvalidString(str, string(abi.encodePacked("String too long for ", context)));
        }
    }

    /**
     * @dev Validate cabinet name (alphanumeric and spaces only)
     * @param name The cabinet name to validate
     */
    function validateCabinetName(string memory name) internal pure {
        validateNonEmptyString(name, "cabinet name");

        bytes memory nameBytes = bytes(name);
        for (uint256 i = 0; i < nameBytes.length; i++) {
            bytes1 char = nameBytes[i];
            bool isValid = (char >= 0x30 && char <= 0x39) || // 0-9
                          (char >= 0x41 && char <= 0x5A) || // A-Z
                          (char >= 0x61 && char <= 0x7A) || // a-z
                          (char == 0x20);                   // space

            if (!isValid) {
                revert InvalidString(name, "Cabinet name contains invalid characters");
            }
        }
    }

    /**
     * @dev Validate ERC721 ownership
     * @param token The ERC721 contract
     * @param owner Expected owner address
     * @param tokenId The token ID to check
     */
    function validateERC721Ownership(
        IERC721 token,
        address owner,
        uint256 tokenId
    ) internal view {
        validateContract(address(token), "ERC721 token");
        validateAddress(owner, "token owner");

        try token.ownerOf(tokenId) returns (address actualOwner) {
            if (actualOwner != owner) {
                revert OwnershipValidationFailed(address(token), owner, tokenId);
            }
        } catch {
            revert OwnershipValidationFailed(address(token), owner, tokenId);
        }
    }

    /**
     * @dev Validate ERC20 balance
     * @param token The ERC20 contract
     * @param account The account to check
     * @param required Required minimum balance
     */
    function validateERC20Balance(
        IERC20 token,
        address account,
        uint256 required
    ) internal view {
        validateContract(address(token), "ERC20 token");
        validateAddress(account, "account holder");

        try token.balanceOf(account) returns (uint256 balance) {
            if (balance < required) {
                revert BalanceValidationFailed(address(token), account, required);
            }
        } catch {
            revert BalanceValidationFailed(address(token), account, required);
        }
    }

    /**
     * @dev Validate ERC20 allowance
     * @param token The ERC20 contract
     * @param owner Token owner
     * @param spender Approved spender
     * @param required Required minimum allowance
     */
    function validateERC20Allowance(
        IERC20 token,
        address owner,
        address spender,
        uint256 required
    ) internal view {
        validateContract(address(token), "ERC20 token");
        validateAddress(owner, "token owner");
        validateAddress(spender, "approved spender");

        try token.allowance(owner, spender) returns (uint256 allowance) {
            if (allowance < required) {
                revert BalanceValidationFailed(address(token), owner, required);
            }
        } catch {
            revert BalanceValidationFailed(address(token), owner, required);
        }
    }

    /**
     * @dev Validate percentage value (0-100)
     * @param percentage The percentage to validate
     * @param context Description of what the percentage represents
     */
    function validatePercentage(uint256 percentage, string memory context) internal pure {
        validateAmount(percentage, 0, 100, context);
    }

    /**
     * @dev Validate basis points value (0-10000, where 10000 = 100%)
     * @param basisPoints The basis points to validate
     * @param context Description of what the basis points represent
     */
    function validateBasisPoints(uint256 basisPoints, string memory context) internal pure {
        validateAmount(basisPoints, 0, 10000, context);
    }

    /**
     * @dev Validate timestamp is in the future
     * @param timestamp The timestamp to validate
     * @param context Description of what the timestamp represents
     */
    function validateFutureTimestamp(uint256 timestamp, string memory context) internal view {
        if (timestamp <= block.timestamp) {
            revert InvalidAmount(timestamp, block.timestamp + 1, type(uint256).max, context);
        }
    }

    /**
     * @dev Validate timestamp is in the past
     * @param timestamp The timestamp to validate
     * @param context Description of what the timestamp represents
     */
    function validatePastTimestamp(uint256 timestamp, string memory context) internal view {
        if (timestamp >= block.timestamp) {
            revert InvalidAmount(timestamp, 0, block.timestamp - 1, context);
        }
    }

    /**
     * @dev Validate marketplace listing parameters
     * @param price Listing price
     * @param duration Listing duration in seconds
     */
    function validateMarketplaceListing(uint256 price, uint256 duration) internal view {
        validateAmount(price, MIN_PLAY_PRICE, type(uint256).max, "listing price");
        validateAmount(duration, 3600, 30 days, "listing duration"); // 1 hour to 30 days
        validateFutureTimestamp(block.timestamp + duration, "listing expiry");
    }

    /**
     * @dev Validate cabinet configuration parameters
     * @param name Cabinet name
     * @param playPrice Play price in wei
     * @param itemCount Number of items in cabinet
     */
    function validateCabinetConfiguration(
        string memory name,
        uint256 playPrice,
        uint256 itemCount
    ) internal pure {
        validateCabinetName(name);
        validatePlayPrice(playPrice);
        validateCabinetItems(itemCount);
    }

    /**
     * @dev Validate that an array has no duplicate addresses
     * @param addresses Array of addresses to check
     */
    function validateNoDuplicateAddresses(address[] memory addresses) internal pure {
        uint256 length = addresses.length;
        for (uint256 i = 0; i < length; i++) {
            validateAddress(addresses[i], "array element");
            for (uint256 j = i + 1; j < length; j++) {
                if (addresses[i] == addresses[j]) {
                    revert InvalidConfiguration("address array", "contains duplicate addresses");
                }
            }
        }
    }

    /**
     * @dev Validate that an array has no duplicate uint256 values
     * @param values Array of values to check
     */
    function validateNoDuplicateValues(uint256[] memory values) internal pure {
        uint256 length = values.length;
        for (uint256 i = 0; i < length; i++) {
            for (uint256 j = i + 1; j < length; j++) {
                if (values[i] == values[j]) {
                    revert InvalidConfiguration("value array", "contains duplicate values");
                }
            }
        }
    }

    /**
     * @dev Validate role expiry duration (reasonable bounds)
     * @param duration Duration in seconds
     */
    function validateRoleExpiryDuration(uint256 duration) internal pure {
        validateAmount(duration, 1 hours, 365 days, "role expiry duration");
    }

    /**
     * @dev Check if a string contains only printable ASCII characters
     * @param str The string to validate
     * @return bool True if string is valid
     */
    function isPrintableASCII(string memory str) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        for (uint256 i = 0; i < strBytes.length; i++) {
            bytes1 char = strBytes[i];
            if (uint8(char) < 32 || uint8(char) > 126) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Validate that a string contains only printable ASCII
     * @param str The string to validate
     * @param context Description of what the string represents
     */
    function validatePrintableASCII(string memory str, string memory context) internal pure {
        if (!isPrintableASCII(str)) {
            revert InvalidString(str, string(abi.encodePacked("Non-printable characters in ", context)));
        }
    }
}