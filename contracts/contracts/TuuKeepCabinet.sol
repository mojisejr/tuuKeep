// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./Utils/Security/TuuKeepAccessControl.sol";
import "./Utils/Security/TuuKeepReentrancyGuard.sol";
import "./Utils/Security/ValidationLib.sol";
import "./Utils/SVGGenerator.sol";
import "./TuuCoin.sol";

/**
 * @title TuuKeepCabinet
 * @dev NFT contract for gachapon cabinet ownership in the TuuKeep platform
 *
 * Features:
 * - ERC-721 NFT representing cabinet ownership
 * - On-chain metadata with dynamic SVG generation
 * - Cabinet configuration and management
 * - Integration with TuuCoin ecosystem
 * - Role-based access control and security
 * - Comprehensive asset management system for gacha items
 *
 * Cabinet Economy:
 * - Cabinet owners can configure play prices and settings
 * - Cabinets generate revenue from player interactions
 * - Dynamic metadata reflects cabinet status and statistics
 * - SVG artwork generated on-chain for each cabinet
 *
 * Asset Management:
 * - Secure deposit/withdrawal of ERC-721 NFTs and ERC-20 tokens
 * - Maximum 10 items per cabinet limitation
 * - Item rarity system (1-5 levels) for gacha mechanics
 * - Active/inactive status management for individual items
 * - Comprehensive validation and security controls
 */
contract TuuKeepCabinet is
    ERC721,
    ERC721Enumerable,
    AccessControl,
    Pausable,
    TuuKeepReentrancyGuard
{
    using Strings for uint256;

    // Access control roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PLATFORM_ADMIN_ROLE = keccak256("PLATFORM_ADMIN_ROLE");
    bytes32 public constant EMERGENCY_RESPONDER_ROLE = keccak256("EMERGENCY_RESPONDER_ROLE");

    // Platform integration
    TuuKeepAccessControl public immutable accessControl;
    TuuCoin public immutable tuuCoin;

    // Cabinet metadata structure
    struct CabinetMetadata {
        string name;                // User-defined cabinet name
        address owner;              // Current cabinet owner
        uint256 createdAt;          // Creation timestamp
        bool isActive;              // Cabinet operational status
        uint256 totalPlays;         // Lifetime play count
        uint256 totalRevenue;       // Lifetime revenue generated (in wei)
        uint256 lastPlayTime;       // Timestamp of last play
    }

    // Cabinet configuration structure
    struct CabinetConfig {
        uint256 playPrice;          // Cost per gacha play (in wei)
        uint256 maxItems;           // Maximum items in cabinet
        uint256 platformFeeRate;    // Platform fee percentage (basis points)
        address feeRecipient;       // Platform fee recipient
        bool allowsCustomOdds;      // Whether TuuCoin burning for odds is allowed
    }

    // Asset type enumeration for gacha items
    enum AssetType {
        ERC721,
        ERC20
    }

    // Gacha item structure for cabinet assets
    struct GachaItem {
        AssetType assetType;        // ERC721 or ERC20
        address contractAddress;    // Token contract address
        uint256 tokenIdOrAmount;    // NFT tokenId or ERC20 amount
        uint256 rarity;             // Rarity level (1-5)
        string metadata;            // Item description/name
        uint256 depositTime;        // When item was deposited
        bool isActive;              // Available for gacha play
    }

    // State variables
    mapping(uint256 => CabinetMetadata) public cabinetMetadata;
    mapping(uint256 => CabinetConfig) public cabinetConfig;

    // Asset management mappings
    mapping(uint256 => GachaItem[]) public cabinetItems;        // Cabinet ID => items array
    mapping(uint256 => mapping(uint256 => bool)) public itemExists;  // Cabinet ID => item index => exists
    mapping(uint256 => uint256) public itemCount;               // Cabinet ID => total items count

    uint256 private _tokenIdCounter;
    uint256 public constant MAX_CABINETS = 10000;
    uint256 public constant DEFAULT_PLATFORM_FEE_RATE = 500;
    uint256 public constant MAX_PLATFORM_FEE_RATE = 1000;
    address public platformFeeRecipient;

    // Events
    event CabinetMinted(
        uint256 indexed tokenId,
        address indexed owner,
        string name,
        uint256 timestamp
    );

    event CabinetConfigured(
        uint256 indexed tokenId,
        CabinetConfig config,
        uint256 timestamp
    );

    event CabinetStatusChanged(
        uint256 indexed tokenId,
        bool isActive,
        uint256 timestamp
    );

    event CabinetStatsUpdated(
        uint256 indexed tokenId,
        uint256 totalPlays,
        uint256 totalRevenue,
        uint256 timestamp
    );

    event CabinetNameChanged(
        uint256 indexed tokenId,
        string oldName,
        string newName,
        uint256 timestamp
    );

    event ItemDeposited(
        uint256 indexed cabinetId,
        uint256 indexed itemIndex,
        AssetType assetType,
        address contractAddress,
        uint256 tokenIdOrAmount,
        uint256 rarity,
        uint256 timestamp
    );

    event ItemWithdrawn(
        uint256 indexed cabinetId,
        uint256 indexed itemIndex,
        AssetType assetType,
        address contractAddress,
        uint256 tokenIdOrAmount,
        uint256 timestamp
    );

    event ItemActivated(
        uint256 indexed cabinetId,
        uint256 indexed itemIndex,
        uint256 timestamp
    );

    event ItemDeactivated(
        uint256 indexed cabinetId,
        uint256 indexed itemIndex,
        uint256 timestamp
    );

    // Custom errors
    error CabinetNotExists(uint256 tokenId);
    error NotCabinetOwner(uint256 tokenId, address caller);
    error CabinetInactive(uint256 tokenId);
    error InvalidConfiguration();
    error MaxCabinetsReached();
    error InvalidFeeRate(uint256 rate);
    error ItemNotFound(uint256 cabinetId, uint256 itemIndex);
    error CabinetFull(uint256 cabinetId, uint256 maxItems);
    error InvalidAssetType(AssetType provided);
    error InvalidRarity(uint256 rarity);
    error DuplicateItem(uint256 cabinetId, address contractAddress, uint256 tokenIdOrAmount);
    error InsufficientAssetBalance(address token, address owner, uint256 required);

    /**
     * @dev Constructor initializes the cabinet NFT contract
     * @param _accessControl Address of the TuuKeep access control contract
     * @param _tuuCoin Address of the TuuCoin token contract
     * @param _platformFeeRecipient Address to receive platform fees
     */
    constructor(
        address _accessControl,
        address _tuuCoin,
        address _platformFeeRecipient
    )
        ERC721("TuuKeep Cabinet", "CABINET")
        TuuKeepReentrancyGuard()
    {
        require(_accessControl != address(0), "Invalid access control address");
        require(_tuuCoin != address(0), "Invalid TuuCoin address");
        require(_platformFeeRecipient != address(0), "Invalid fee recipient");

        accessControl = TuuKeepAccessControl(_accessControl);
        tuuCoin = TuuCoin(_tuuCoin);
        platformFeeRecipient = _platformFeeRecipient;

        // Grant roles to deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PLATFORM_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(EMERGENCY_RESPONDER_ROLE, msg.sender);
    }

    // Modifiers
    modifier onlyTokenOwner(uint256 tokenId) {
        if (ownerOf(tokenId) != msg.sender) {
            revert NotCabinetOwner(tokenId, msg.sender);
        }
        _;
    }

    modifier cabinetExists(uint256 tokenId) {
        if (_ownerOf(tokenId) == address(0)) {
            revert CabinetNotExists(tokenId);
        }
        _;
    }

    modifier onlyActiveCabinet(uint256 tokenId) {
        if (!cabinetMetadata[tokenId].isActive) {
            revert CabinetInactive(tokenId);
        }
        _;
    }

    /**
     * @dev Mint a new cabinet NFT
     * @param to Address to receive the cabinet NFT
     * @param cabinetName Name for the cabinet
     * @return tokenId The ID of the newly minted cabinet
     */
    function mintCabinet(
        address to,
        string memory cabinetName
    )
        external
        onlyRole(MINTER_ROLE)
        nonReentrant
        returns (uint256)
    {
        require(to != address(0), "Invalid address");
        ValidationLib.validateNonEmptyString(cabinetName, "cabinet name");

        if (_tokenIdCounter >= MAX_CABINETS) {
            revert MaxCabinetsReached();
        }

        uint256 tokenId = _tokenIdCounter++;

        // Initialize cabinet metadata
        cabinetMetadata[tokenId] = CabinetMetadata({
            name: cabinetName,
            owner: to,
            createdAt: block.timestamp,
            isActive: false, // Starts inactive until configured
            totalPlays: 0,
            totalRevenue: 0,
            lastPlayTime: 0
        });

        // Initialize default configuration
        cabinetConfig[tokenId] = CabinetConfig({
            playPrice: 0.01 ether, // Default play price
            maxItems: 10,
            platformFeeRate: DEFAULT_PLATFORM_FEE_RATE,
            feeRecipient: platformFeeRecipient,
            allowsCustomOdds: true
        });

        // Mint the NFT
        _safeMint(to, tokenId);

        // Register cabinet with TuuCoin contract
        _registerCabinetWithTuuCoin(tokenId);

        emit CabinetMinted(tokenId, to, cabinetName, block.timestamp);

        return tokenId;
    }

    /**
     * @dev Set cabinet name (only owner)
     * @param tokenId Cabinet token ID
     * @param newName New name for the cabinet
     */
    function setCabinetName(
        uint256 tokenId,
        string memory newName
    )
        external
        onlyTokenOwner(tokenId)
        cabinetExists(tokenId)
        nonReentrant
    {
        ValidationLib.validateNonEmptyString(newName, "cabinet name");

        string memory oldName = cabinetMetadata[tokenId].name;
        cabinetMetadata[tokenId].name = newName;

        emit CabinetNameChanged(tokenId, oldName, newName, block.timestamp);
    }

    /**
     * @dev Configure cabinet settings (only owner)
     * @param tokenId Cabinet token ID
     * @param config New configuration for the cabinet
     */
    function setCabinetConfig(
        uint256 tokenId,
        CabinetConfig memory config
    )
        external
        onlyTokenOwner(tokenId)
        cabinetExists(tokenId)
        nonReentrant
    {
        require(config.playPrice > 0, "Invalid price");
        require(config.maxItems > 0 && config.maxItems <= 50, "Invalid items");
        require(config.feeRecipient != address(0), "Invalid recipient");

        if (config.platformFeeRate > MAX_PLATFORM_FEE_RATE) {
            revert InvalidFeeRate(config.platformFeeRate);
        }

        cabinetConfig[tokenId] = config;

        emit CabinetConfigured(tokenId, config, block.timestamp);
    }

    /**
     * @dev Activate cabinet for gameplay
     * @param tokenId Cabinet token ID
     */
    function activateCabinet(uint256 tokenId)
        external
        onlyTokenOwner(tokenId)
        cabinetExists(tokenId)
        nonReentrant
    {
        cabinetMetadata[tokenId].isActive = true;

        // Update status in TuuCoin contract
        tuuCoin.updateCabinetStatus(tokenId, true);

        emit CabinetStatusChanged(tokenId, true, block.timestamp);
    }

    /**
     * @dev Deactivate cabinet (pause gameplay)
     * @param tokenId Cabinet token ID
     */
    function deactivateCabinet(uint256 tokenId)
        external
        onlyTokenOwner(tokenId)
        cabinetExists(tokenId)
        nonReentrant
    {
        cabinetMetadata[tokenId].isActive = false;

        // Update status in TuuCoin contract
        tuuCoin.updateCabinetStatus(tokenId, false);

        emit CabinetStatusChanged(tokenId, false, block.timestamp);
    }

    /**
     * @dev Deposit items into cabinet for gacha gameplay
     * @param cabinetId Cabinet token ID
     * @param items Array of gacha items to deposit
     */
    function depositItems(
        uint256 cabinetId,
        GachaItem[] calldata items
    )
        external
        onlyTokenOwner(cabinetId)
        cabinetExists(cabinetId)
        nonReentrant
    {
        require(items.length > 0, "No items provided");

        // Check cabinet item limit
        uint256 currentCount = itemCount[cabinetId];
        uint256 newCount = currentCount + items.length;

        ValidationLib.validateCabinetItems(newCount);

        if (newCount > ValidationLib.MAX_CABINET_ITEMS) {
            revert CabinetFull(cabinetId, ValidationLib.MAX_CABINET_ITEMS);
        }

        // Process each item
        for (uint256 i = 0; i < items.length; i++) {
            GachaItem calldata item = items[i];

            // Validate item data
            _validateGachaItem(item, cabinetId);

            // Transfer asset to contract for escrow
            _transferAssetToContract(item, msg.sender);

            // Add item to storage
            uint256 itemIndex = cabinetItems[cabinetId].length;

            GachaItem memory newItem = GachaItem({
                assetType: item.assetType,
                contractAddress: item.contractAddress,
                tokenIdOrAmount: item.tokenIdOrAmount,
                rarity: item.rarity,
                metadata: item.metadata,
                depositTime: block.timestamp,
                isActive: true
            });

            cabinetItems[cabinetId].push(newItem);
            itemExists[cabinetId][itemIndex] = true;

            emit ItemDeposited(
                cabinetId,
                itemIndex,
                item.assetType,
                item.contractAddress,
                item.tokenIdOrAmount,
                item.rarity,
                block.timestamp
            );
        }

        // Update item count
        itemCount[cabinetId] = newCount;
    }

    /**
     * @dev Withdraw items from cabinet (cabinet owner only)
     * @param cabinetId Cabinet token ID
     * @param itemIndices Array of item indices to withdraw
     */
    function withdrawItems(
        uint256 cabinetId,
        uint256[] calldata itemIndices
    )
        external
        onlyTokenOwner(cabinetId)
        cabinetExists(cabinetId)
        nonReentrant
    {
        require(itemIndices.length > 0, "No items specified");

        address cabinetOwner = ownerOf(cabinetId);

        // Process withdrawals in reverse order to avoid index shifting issues
        for (uint256 i = itemIndices.length; i > 0; i--) {
            uint256 itemIndex = itemIndices[i - 1];

            if (itemIndex >= cabinetItems[cabinetId].length) {
                revert ItemNotFound(cabinetId, itemIndex);
            }

            if (!itemExists[cabinetId][itemIndex]) {
                revert ItemNotFound(cabinetId, itemIndex);
            }

            GachaItem storage item = cabinetItems[cabinetId][itemIndex];

            // Transfer asset back to owner
            _transferAssetFromContract(item, cabinetOwner);

            emit ItemWithdrawn(
                cabinetId,
                itemIndex,
                item.assetType,
                item.contractAddress,
                item.tokenIdOrAmount,
                block.timestamp
            );

            // Remove item from storage
            _removeItem(cabinetId, itemIndex);
        }

        // Update item count
        itemCount[cabinetId] = cabinetItems[cabinetId].length;
    }

    /**
     * @dev Update cabinet statistics (internal use)
     * @param tokenId Cabinet token ID
     * @param additionalPlays Number of new plays to add
     * @param additionalRevenue Additional revenue to add (in wei)
     */
    function updateCabinetStats(
        uint256 tokenId,
        uint256 additionalPlays,
        uint256 additionalRevenue
    )
        internal
        cabinetExists(tokenId)
    {
        CabinetMetadata storage metadata = cabinetMetadata[tokenId];
        metadata.totalPlays += additionalPlays;
        metadata.totalRevenue += additionalRevenue;
        metadata.lastPlayTime = block.timestamp;

        emit CabinetStatsUpdated(
            tokenId,
            metadata.totalPlays,
            metadata.totalRevenue,
            block.timestamp
        );
    }

    /**
     * @dev Generate token URI with on-chain metadata and SVG
     * @param tokenId Cabinet token ID
     * @return JSON metadata string
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        cabinetExists(tokenId)
        returns (string memory)
    {
        CabinetMetadata memory metadata = cabinetMetadata[tokenId];
        CabinetConfig memory config = cabinetConfig[tokenId];

        string memory svg = _generateSVG(tokenId);

        // Create JSON metadata
        string memory json = string(abi.encodePacked(
            '{"name": "TuuKeep Cabinet #', tokenId.toString(), '",',
            '"description": "A gachapon cabinet NFT in the TuuKeep decentralized platform",',
            '"image": "data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '",',
            '"attributes": [',
            '{"trait_type": "Cabinet Name", "value": "', metadata.name, '"},',
            '{"trait_type": "Status", "value": "', metadata.isActive ? "Active" : "Inactive", '"},',
            '{"trait_type": "Total Plays", "value": ', metadata.totalPlays.toString(), '},',
            '{"trait_type": "Total Revenue", "value": ', metadata.totalRevenue.toString(), '},',
            '{"trait_type": "Play Price", "value": ', config.playPrice.toString(), '},',
            '{"trait_type": "Max Items", "value": ', config.maxItems.toString(), '},',
            '{"trait_type": "Created At", "value": ', metadata.createdAt.toString(), '}',
            ']}'
        ));

        return string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
        ));
    }

    /**
     * @dev Validate gacha item data
     * @param item The gacha item to validate
     * @param cabinetId Cabinet ID for context
     */
    function _validateGachaItem(GachaItem calldata item, uint256 cabinetId) internal view {
        // Validate contract address
        ValidationLib.validateContract(item.contractAddress, "asset contract");

        // Validate rarity (1-5)
        if (item.rarity < 1 || item.rarity > 5) {
            revert InvalidRarity(item.rarity);
        }

        // Validate metadata string
        ValidationLib.validateNonEmptyString(item.metadata, "item metadata");

        // Validate asset-specific requirements
        if (item.assetType == AssetType.ERC721) {
            // For ERC721, validate ownership
            ValidationLib.validateERC721Ownership(
                IERC721(item.contractAddress),
                msg.sender,
                item.tokenIdOrAmount
            );
        } else if (item.assetType == AssetType.ERC20) {
            // For ERC20, validate balance and allowance
            ValidationLib.validateERC20Balance(
                IERC20(item.contractAddress),
                msg.sender,
                item.tokenIdOrAmount
            );

            ValidationLib.validateERC20Allowance(
                IERC20(item.contractAddress),
                msg.sender,
                address(this),
                item.tokenIdOrAmount
            );
        } else {
            revert InvalidAssetType(item.assetType);
        }

        // Check for duplicate items in cabinet
        _validateNoDuplicateItem(cabinetId, item.contractAddress, item.tokenIdOrAmount);
    }

    /**
     * @dev Check for duplicate items in cabinet
     * @param cabinetId Cabinet ID
     * @param contractAddress Asset contract address
     * @param tokenIdOrAmount Token ID or amount
     */
    function _validateNoDuplicateItem(
        uint256 cabinetId,
        address contractAddress,
        uint256 tokenIdOrAmount
    ) internal view {
        GachaItem[] storage items = cabinetItems[cabinetId];
        for (uint256 i = 0; i < items.length; i++) {
            if (items[i].contractAddress == contractAddress &&
                items[i].tokenIdOrAmount == tokenIdOrAmount) {
                revert DuplicateItem(cabinetId, contractAddress, tokenIdOrAmount);
            }
        }
    }

    /**
     * @dev Transfer asset from user to contract for escrow
     * @param item The gacha item to transfer
     * @param from Address to transfer from
     */
    function _transferAssetToContract(GachaItem calldata item, address from) internal {
        if (item.assetType == AssetType.ERC721) {
            IERC721(item.contractAddress).safeTransferFrom(
                from,
                address(this),
                item.tokenIdOrAmount
            );
        } else if (item.assetType == AssetType.ERC20) {
            bool success = IERC20(item.contractAddress).transferFrom(
                from,
                address(this),
                item.tokenIdOrAmount
            );
            require(success, "ERC20 transfer failed");
        }
    }

    /**
     * @dev Transfer asset from contract back to user
     * @param item The gacha item to transfer
     * @param to Address to transfer to
     */
    function _transferAssetFromContract(GachaItem storage item, address to) internal {
        if (item.assetType == AssetType.ERC721) {
            IERC721(item.contractAddress).safeTransferFrom(
                address(this),
                to,
                item.tokenIdOrAmount
            );
        } else if (item.assetType == AssetType.ERC20) {
            bool success = IERC20(item.contractAddress).transfer(
                to,
                item.tokenIdOrAmount
            );
            require(success, "ERC20 transfer failed");
        }
    }

    /**
     * @dev Remove item from cabinet storage
     * @param cabinetId Cabinet ID
     * @param itemIndex Index of item to remove
     */
    function _removeItem(uint256 cabinetId, uint256 itemIndex) internal {
        GachaItem[] storage items = cabinetItems[cabinetId];
        uint256 lastIndex = items.length - 1;

        // Move last item to the position being removed
        if (itemIndex != lastIndex) {
            items[itemIndex] = items[lastIndex];
            // Update existence mapping for moved item
            itemExists[cabinetId][itemIndex] = true;
        }

        // Remove last item and update existence mapping
        items.pop();
        itemExists[cabinetId][lastIndex] = false;

        // If we moved an item, clear its old position
        if (itemIndex != lastIndex) {
            itemExists[cabinetId][lastIndex] = false;
        }
    }

    /**
     * @dev Generate dynamic SVG for cabinet NFT using external library
     * @param tokenId Cabinet token ID
     * @return SVG string
     */
    function _generateSVG(uint256 tokenId)
        internal
        view
        returns (string memory)
    {
        CabinetMetadata memory metadata = cabinetMetadata[tokenId];
        return SVGGenerator.generateCabinetSVG(
            tokenId,
            metadata.name,
            metadata.isActive,
            metadata.totalPlays
        );
    }

    /**
     * @dev Register cabinet with TuuCoin contract
     * @param tokenId Cabinet token ID
     */
    function _registerCabinetWithTuuCoin(uint256 tokenId) internal {
        try tuuCoin.registerCabinet(tokenId, ownerOf(tokenId)) {
            // Cabinet registration successful
        } catch {
            // Registration failed, but don't revert the mint
            // This allows the contract to work even if TuuCoin registration fails
        }
    }

    /**
     * @dev Get cabinet information
     * @param tokenId Cabinet token ID
     * @return metadata Cabinet metadata
     * @return config Cabinet configuration
     */
    function getCabinetInfo(uint256 tokenId)
        external
        view
        cabinetExists(tokenId)
        returns (CabinetMetadata memory metadata, CabinetConfig memory config)
    {
        return (cabinetMetadata[tokenId], cabinetConfig[tokenId]);
    }

    /**
     * @dev Get all items in a cabinet
     * @param cabinetId Cabinet token ID
     * @return Array of gacha items
     */
    function getCabinetItems(uint256 cabinetId)
        external
        view
        cabinetExists(cabinetId)
        returns (GachaItem[] memory)
    {
        return cabinetItems[cabinetId];
    }

    /**
     * @dev Get specific item from cabinet
     * @param cabinetId Cabinet token ID
     * @param itemIndex Index of the item
     * @return The gacha item
     */
    function getCabinetItem(uint256 cabinetId, uint256 itemIndex)
        external
        view
        cabinetExists(cabinetId)
        returns (GachaItem memory)
    {
        require(itemIndex < cabinetItems[cabinetId].length, "Item index out of bounds");
        require(itemExists[cabinetId][itemIndex], "Item does not exist");
        return cabinetItems[cabinetId][itemIndex];
    }

    /**
     * @dev Get number of items in cabinet
     * @param cabinetId Cabinet token ID
     * @return Number of items
     */
    function getCabinetItemCount(uint256 cabinetId)
        external
        view
        cabinetExists(cabinetId)
        returns (uint256)
    {
        return itemCount[cabinetId];
    }

    /**
     * @dev Get active items in cabinet (available for gacha play)
     * @param cabinetId Cabinet token ID
     * @return Array of active gacha items
     */
    function getActiveCabinetItems(uint256 cabinetId)
        external
        view
        cabinetExists(cabinetId)
        returns (GachaItem[] memory)
    {
        GachaItem[] memory allItems = cabinetItems[cabinetId];
        uint256 activeCount = 0;

        // Count active items
        for (uint256 i = 0; i < allItems.length; i++) {
            if (allItems[i].isActive) {
                activeCount++;
            }
        }

        // Create array of active items
        GachaItem[] memory activeItems = new GachaItem[](activeCount);
        uint256 activeIndex = 0;

        for (uint256 i = 0; i < allItems.length; i++) {
            if (allItems[i].isActive) {
                activeItems[activeIndex] = allItems[i];
                activeIndex++;
            }
        }

        return activeItems;
    }

    /**
     * @dev Toggle item active status (cabinet owner only)
     * @param cabinetId Cabinet token ID
     * @param itemIndex Index of item to toggle
     */
    function toggleItemStatus(uint256 cabinetId, uint256 itemIndex)
        external
        onlyTokenOwner(cabinetId)
        cabinetExists(cabinetId)
        nonReentrant
    {
        require(itemIndex < cabinetItems[cabinetId].length, "Item index out of bounds");
        require(itemExists[cabinetId][itemIndex], "Item does not exist");

        GachaItem storage item = cabinetItems[cabinetId][itemIndex];
        item.isActive = !item.isActive;

        if (item.isActive) {
            emit ItemActivated(cabinetId, itemIndex, block.timestamp);
        } else {
            emit ItemDeactivated(cabinetId, itemIndex, block.timestamp);
        }
    }

    /**
     * @dev Get total number of cabinets minted
     * @return Total cabinet count
     */
    function totalCabinets() external view returns (uint256) {
        return _tokenIdCounter;
    }

    /**
     * @dev Pause contract (emergency use only)
     */
    function pause() external onlyRole(EMERGENCY_RESPONDER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyRole(EMERGENCY_RESPONDER_ROLE) {
        _unpause();
    }

    /**
     * @dev Update platform fee recipient
     * @param newRecipient New fee recipient address
     */
    function updatePlatformFeeRecipient(address newRecipient)
        external
        onlyRole(PLATFORM_ADMIN_ROLE)
    {
        require(newRecipient != address(0), "Invalid address");
        platformFeeRecipient = newRecipient;
    }

    // Override required by Solidity for multiple inheritance
    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function _update(address to, uint256 tokenId, address auth) internal override(ERC721, ERC721Enumerable) whenNotPaused returns (address) {
        address previousOwner = super._update(to, tokenId, auth);

        // Update cabinet owner in metadata when transferred
        if (previousOwner != address(0) && to != address(0)) {
            cabinetMetadata[tokenId].owner = to;
        }

        return previousOwner;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}