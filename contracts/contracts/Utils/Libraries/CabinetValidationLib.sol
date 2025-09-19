// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../Security/ValidationLib.sol";
/**
 * @title CabinetValidationLib
 * @dev Library for cabinet-specific validation logic
 */
library CabinetValidationLib {

    // Enums and Structs
    enum AssetType { ERC721, ERC20, ERC1155 }

    struct GachaItem {
        AssetType assetType;
        address contractAddress;
        uint256 tokenIdOrAmount;
        uint256 rarity;
        bool isActive;
        uint256 depositedAt;
        address depositor;
        uint256 withdrawableAfter;
    }

    // Custom errors
    error InvalidCabinetOwner(uint256 cabinetId, address expected, address actual);
    error CabinetNotActive(uint256 cabinetId);
    error InvalidItemConfiguration(string reason);
    error CabinetCapacityExceeded(uint256 cabinetId, uint256 maxItems);
    error ItemValidationFailed(string reason);

    /**
     * @dev Validate cabinet ownership
     */
    function validateCabinetOwnership(
        address cabinetContract,
        uint256 cabinetId,
        address expectedOwner
    ) internal view {
        IERC721 cabinet = IERC721(cabinetContract);
        address actualOwner = cabinet.ownerOf(cabinetId);

        if (actualOwner != expectedOwner) {
            revert InvalidCabinetOwner(cabinetId, expectedOwner, actualOwner);
        }
    }

    /**
     * @dev Validate cabinet is active
     */
    function validateCabinetActive(
        address cabinetContract,
        uint256 cabinetId
    ) internal view {
        (bool success, bytes memory data) = cabinetContract.staticcall(
            abi.encodeWithSignature("isActiveCabinet(uint256)", cabinetId)
        );

        if (!success) {
            revert CabinetNotActive(cabinetId);
        }

        bool isActive = abi.decode(data, (bool));
        if (!isActive) {
            revert CabinetNotActive(cabinetId);
        }
    }

    /**
     * @dev Validate gacha item parameters
     */
    function validateGachaItem(
        AssetType assetType,
        address contractAddress,
        uint256 tokenIdOrAmount,
        uint256 rarity,
        address owner
    ) internal view {
        ValidationLib.validateContract(contractAddress, "asset contract");

        if (rarity == 0 || rarity > 4) {
            revert ItemValidationFailed("Invalid rarity: must be 1-4");
        }

        if (assetType == AssetType.ERC721) {
            ValidationLib.validateERC721Ownership(
                IERC721(contractAddress),
                owner,
                tokenIdOrAmount
            );
        } else if (assetType == AssetType.ERC20) {
            ValidationLib.validateERC20Balance(
                IERC20(contractAddress),
                owner,
                tokenIdOrAmount
            );
        } else if (assetType == AssetType.ERC1155) {
            uint256 balance = IERC1155(contractAddress).balanceOf(owner, tokenIdOrAmount);
            if (balance == 0) {
                revert ItemValidationFailed("Insufficient ERC1155 balance");
            }
        } else {
            revert ItemValidationFailed("Invalid asset type");
        }
    }

    /**
     * @dev Validate cabinet capacity
     */
    function validateCabinetCapacity(
        uint256 currentItemCount,
        uint256 newItemCount,
        uint256 maxItems
    ) internal pure {
        if (currentItemCount + newItemCount > maxItems) {
            revert CabinetCapacityExceeded(0, maxItems);
        }
    }

    /**
     * @dev Validate cabinet configuration parameters
     */
    function validateCabinetConfig(
        uint256 playPrice,
        uint256 maxItems,
        uint256 platformFeeRate
    ) internal pure {
        ValidationLib.validatePlayPrice(playPrice);
        ValidationLib.validateAmount(maxItems, 1, ValidationLib.MAX_CABINET_ITEMS, "max items");
        ValidationLib.validateBasisPoints(platformFeeRate, "platform fee rate");
    }

    /**
     * @dev Validate item withdrawal conditions
     */
    function validateItemWithdrawal(
        uint256 depositedAt,
        uint256 withdrawableAfter,
        bool isActive
    ) internal view {
        if (block.timestamp < withdrawableAfter) {
            revert ItemValidationFailed("Item is still locked");
        }

        if (!isActive) {
            revert ItemValidationFailed("Item is not active");
        }
    }

    /**
     * @dev Validate marketplace listing parameters
     */
    function validateListingParameters(
        uint256 price,
        uint256 duration,
        uint256 minPrice,
        uint256 minDuration,
        uint256 maxDuration
    ) internal pure {
        if (price < minPrice) {
            revert ItemValidationFailed("Price below minimum");
        }

        if (duration < minDuration || duration > maxDuration) {
            revert ItemValidationFailed("Invalid duration");
        }
    }

    /**
     * @dev Validate cabinet approval for marketplace operations
     */
    function validateCabinetApproval(
        address cabinetContract,
        uint256 cabinetId,
        address owner,
        address marketplace
    ) internal view {
        IERC721 cabinet = IERC721(cabinetContract);

        bool isApproved = (cabinet.getApproved(cabinetId) == marketplace) ||
                         cabinet.isApprovedForAll(owner, marketplace);

        if (!isApproved) {
            revert ItemValidationFailed("Cabinet not approved for marketplace");
        }
    }

    /**
     * @dev Check if an item already exists in cabinet (prevent duplicates)
     */
    function validateNoDuplicateItem(
        GachaItem[] memory existingItems,
        address contractAddress,
        uint256 tokenIdOrAmount
    ) internal pure {
        for (uint256 i = 0; i < existingItems.length; i++) {
            if (existingItems[i].contractAddress == contractAddress &&
                existingItems[i].tokenIdOrAmount == tokenIdOrAmount) {
                revert ItemValidationFailed("Duplicate item");
            }
        }
    }

    /**
     * @dev Validate cabinet state for specific operations
     */
    function validateCabinetOperationState(
        bool isActive,
        bool inMaintenance,
        bool hasItems,
        string memory operation
    ) internal pure {
        if (keccak256(abi.encodePacked(operation)) == keccak256("play")) {
            if (!isActive) {
                revert CabinetNotActive(0);
            }
            if (inMaintenance) {
                revert ItemValidationFailed("Cabinet in maintenance");
            }
            if (!hasItems) {
                revert ItemValidationFailed("No items in cabinet");
            }
        } else if (keccak256(abi.encodePacked(operation)) == keccak256("activate")) {
            if (!hasItems) {
                revert ItemValidationFailed("Cannot activate cabinet without items");
            }
        }
    }

    /**
     * @dev Validate rarity distribution for cabinet balance
     */
    function validateRarityDistribution(
        uint256[] memory rarityCounts,
        uint256 minItemsPerRarity
    ) internal pure {
        for (uint256 i = 0; i < rarityCounts.length; i++) {
            if (rarityCounts[i] > 0 && rarityCounts[i] < minItemsPerRarity) {
                revert ItemValidationFailed("Insufficient items for rarity tier");
            }
        }
    }
}