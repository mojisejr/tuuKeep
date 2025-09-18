// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title ITuuKeepCabinetCore
 * @dev Interface for TuuKeepCabinetCore contract
 */
interface ITuuKeepCabinetCore is IERC721 {
    // Enums
    enum AssetType { ERC721, ERC20, ERC1155 }

    // Structs
    struct CabinetMetadata {
        string name;
        address owner;
        uint256 createdAt;
        bool isActive;
        uint256 totalPlays;
        uint256 totalRevenue;
        uint256 lastPlayTime;
    }

    struct CabinetConfig {
        uint256 playPrice;
        bool requiresDeposit;
        uint256 maxItems;
        uint256 platformFeeRate;
        bool inMaintenance;
        address feeRecipient;
    }

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

    // Events
    event CabinetMinted(uint256 indexed tokenId, address indexed owner, string name);
    event CabinetConfigured(uint256 indexed tokenId, uint256 playPrice);
    event CabinetStatusChanged(uint256 indexed tokenId, bool isActive);
    event PriceUpdated(uint256 indexed tokenId, uint256 oldPrice, uint256 newPrice);
    event ItemDeposited(uint256 indexed cabinetId, uint256 indexed itemIndex, AssetType assetType, address contractAddress, uint256 tokenIdOrAmount, uint256 rarity);
    event ItemWithdrawn(uint256 indexed cabinetId, uint256 indexed itemIndex, AssetType assetType);
    event ItemStatusChanged(uint256 indexed cabinetId, uint256 indexed itemIndex, bool isActive);

    // Core Functions
    function mintCabinet(address to, string calldata name, uint256 playPrice) external returns (uint256);
    function setCabinetName(uint256 tokenId, string calldata newName) external;
    function setCabinetConfig(uint256 tokenId, uint256 playPrice, uint256 maxItems, bool requiresDeposit) external;
    function activateCabinet(uint256 tokenId) external;
    function deactivateCabinet(uint256 tokenId) external;
    function setPrice(uint256 tokenId, uint256 newPrice) external;
    function setMaintenanceMode(uint256 tokenId, bool inMaintenance) external;

    // Item Management
    function depositItems(uint256 cabinetId, GachaItem[] calldata items) external;
    function withdrawItems(uint256 cabinetId, uint256[] calldata itemIndices) external;
    function toggleItemStatus(uint256 cabinetId, uint256 itemIndex) external;

    // View Functions
    function getCabinetInfo(uint256 tokenId) external view returns (CabinetMetadata memory, CabinetConfig memory);
    function getCabinetItems(uint256 cabinetId) external view returns (GachaItem[] memory);
    function getCabinetItem(uint256 cabinetId, uint256 itemIndex) external view returns (GachaItem memory);
    function getCabinetItemCount(uint256 cabinetId) external view returns (uint256);
    function getActiveCabinetItems(uint256 cabinetId) external view returns (GachaItem[] memory);

    // Game Interface Functions
    function updateCabinetStats(uint256 cabinetId, uint256 revenue, uint256 platformFee) external;
    function transferItemToPlayer(uint256 cabinetId, uint256 itemIndex, address player) external;
    function isActiveCabinet(uint256 cabinetId) external view returns (bool);
    function getCabinetOwner(uint256 cabinetId) external view returns (address);
    function getCabinetPlayPrice(uint256 cabinetId) external view returns (uint256);
}