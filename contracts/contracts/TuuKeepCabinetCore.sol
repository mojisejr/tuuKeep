// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./Utils/Security/TuuKeepAccessControl.sol";
import "./Utils/Security/TuuKeepReentrancyGuard.sol";
import "./Utils/Security/ValidationLib.sol";
import "./Utils/SVGGenerator.sol";
import "./Utils/TuuKeepErrors.sol";
import "./interfaces/ITuuKeepCabinetCore.sol";
import "./interfaces/ITuuKeepCabinetGame.sol";

/**
 * @title TuuKeepCabinetCore
 * @dev Core NFT contract for TuuKeep Cabinet system
 * Handles minting, metadata, configuration, and item management
 */
contract TuuKeepCabinetCore is
    ERC721,
    ERC721Enumerable,
    AccessControl,
    Pausable,
    TuuKeepReentrancyGuard,
    ITuuKeepCabinetCore
{
    using Strings for uint256;

    // Access control roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PLATFORM_ADMIN_ROLE = keccak256("PLATFORM_ADMIN_ROLE");
    bytes32 public constant EMERGENCY_RESPONDER_ROLE = keccak256("EMERGENCY_RESPONDER_ROLE");
    bytes32 public constant GAME_CONTRACT_ROLE = keccak256("GAME_CONTRACT_ROLE");

    // Platform integration
    TuuKeepAccessControl public immutable accessControl;
    address public gameContract;

    // Constants
    uint256 public constant MAX_CABINETS_PER_OWNER = 10;
    uint256 public constant DEFAULT_PLATFORM_FEE_RATE = 500; // 5%
    uint256 public constant MAX_PLATFORM_FEE_RATE = 2000; // 20%

    // Storage
    mapping(uint256 => CabinetMetadata) private _cabinetMetadata;
    mapping(uint256 => CabinetConfig) private _cabinetConfigs;
    mapping(uint256 => GachaItem[]) private _cabinetItems;
    mapping(address => uint256) private _ownerCabinetCount;

    // Revenue tracking
    mapping(uint256 => uint256) private _cabinetRevenue;
    uint256 private _platformRevenue;

    // Platform settings
    address public platformFeeRecipient;
    uint256 public platformFeeRate = DEFAULT_PLATFORM_FEE_RATE;

    // Current token ID counter
    uint256 private _currentTokenId = 0;

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
    error OnlyGameContract();

    modifier onlyTokenOwner(uint256 tokenId) {
        if (ownerOf(tokenId) != msg.sender) {
            revert NotCabinetOwner(tokenId, msg.sender);
        }
        _;
    }

    modifier cabinetExists(uint256 tokenId) {
        if (!_exists(tokenId)) {
            revert CabinetNotExists(tokenId);
        }
        _;
    }

    modifier onlyActiveCabinet(uint256 tokenId) {
        if (!_cabinetMetadata[tokenId].isActive) {
            revert CabinetInactive(tokenId);
        }
        _;
    }

    modifier onlyGameContract() {
        if (msg.sender != gameContract) {
            revert OnlyGameContract();
        }
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        address _accessControl,
        address _platformFeeRecipient
    ) ERC721(name, symbol) {
        accessControl = TuuKeepAccessControl(_accessControl);
        platformFeeRecipient = _platformFeeRecipient;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PLATFORM_ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_RESPONDER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    /**
     * @dev Set the game contract address (can only be called by admin)
     */
    function setGameContract(address _gameContract) external onlyRole(PLATFORM_ADMIN_ROLE) {
        ValidationLib.validateContract(_gameContract, "game contract");
        gameContract = _gameContract;
        _grantRole(GAME_CONTRACT_ROLE, _gameContract);
    }

    /**
     * @dev Mint a new cabinet NFT
     */
    function mintCabinet(
        address to,
        string calldata name,
        uint256 playPrice
    ) external onlyRole(MINTER_ROLE) whenNotPaused returns (uint256) {
        ValidationLib.validateAddress(to, "recipient");
        ValidationLib.validateNonEmptyString(name, "cabinet name");
        ValidationLib.validatePlayPrice(playPrice);

        if (_ownerCabinetCount[to] >= MAX_CABINETS_PER_OWNER) {
            revert MaxCabinetsReached();
        }

        uint256 tokenId = ++_currentTokenId;

        // Initialize cabinet metadata
        _cabinetMetadata[tokenId] = CabinetMetadata({
            name: name,
            owner: to,
            createdAt: block.timestamp,
            isActive: false,
            totalPlays: 0,
            totalRevenue: 0,
            lastPlayTime: 0
        });

        // Initialize cabinet configuration
        _cabinetConfigs[tokenId] = CabinetConfig({
            playPrice: playPrice,
            requiresDeposit: true,
            maxItems: ValidationLib.MAX_CABINET_ITEMS,
            platformFeeRate: platformFeeRate,
            inMaintenance: false,
            feeRecipient: platformFeeRecipient
        });

        _ownerCabinetCount[to]++;
        _safeMint(to, tokenId);

        emit CabinetMinted(tokenId, to, name);
        emit CabinetConfigured(tokenId, playPrice);

        return tokenId;
    }

    /**
     * @dev Set cabinet name
     */
    function setCabinetName(
        uint256 tokenId,
        string calldata newName
    ) external cabinetExists(tokenId) onlyTokenOwner(tokenId) {
        ValidationLib.validateNonEmptyString(newName, "cabinet name");

        _cabinetMetadata[tokenId].name = newName;
    }

    /**
     * @dev Configure cabinet settings
     */
    function setCabinetConfig(
        uint256 tokenId,
        uint256 playPrice,
        uint256 maxItems,
        bool requiresDeposit
    ) external cabinetExists(tokenId) onlyTokenOwner(tokenId) {
        ValidationLib.validatePlayPrice(playPrice);
        ValidationLib.validateAmount(maxItems, 1, ValidationLib.MAX_CABINET_ITEMS, "max items");

        CabinetConfig storage config = _cabinetConfigs[tokenId];
        config.playPrice = playPrice;
        config.maxItems = maxItems;
        config.requiresDeposit = requiresDeposit;

        emit CabinetConfigured(tokenId, playPrice);
    }

    /**
     * @dev Activate cabinet for gameplay
     */
    function activateCabinet(uint256 tokenId)
        external
        cabinetExists(tokenId)
        onlyTokenOwner(tokenId)
    {
        require(_cabinetItems[tokenId].length > 0, "No items in cabinet");

        _cabinetMetadata[tokenId].isActive = true;
        emit CabinetStatusChanged(tokenId, true);
    }

    /**
     * @dev Deactivate cabinet
     */
    function deactivateCabinet(uint256 tokenId)
        external
        cabinetExists(tokenId)
        onlyTokenOwner(tokenId)
    {
        _cabinetMetadata[tokenId].isActive = false;
        emit CabinetStatusChanged(tokenId, false);
    }

    /**
     * @dev Update cabinet play price
     */
    function setPrice(uint256 tokenId, uint256 newPrice)
        external
        cabinetExists(tokenId)
        onlyTokenOwner(tokenId)
    {
        ValidationLib.validatePlayPrice(newPrice);

        uint256 oldPrice = _cabinetConfigs[tokenId].playPrice;
        _cabinetConfigs[tokenId].playPrice = newPrice;

        emit PriceUpdated(tokenId, oldPrice, newPrice);
    }

    /**
     * @dev Set maintenance mode for cabinet
     */
    function setMaintenanceMode(uint256 tokenId, bool inMaintenance)
        external
        cabinetExists(tokenId)
        onlyTokenOwner(tokenId)
    {
        _cabinetConfigs[tokenId].inMaintenance = inMaintenance;

        if (inMaintenance) {
            _cabinetMetadata[tokenId].isActive = false;
            emit CabinetStatusChanged(tokenId, false);
        }
    }

    /**
     * @dev Deposit items into cabinet
     */
    function depositItems(
        uint256 cabinetId,
        GachaItem[] calldata items
    ) external cabinetExists(cabinetId) onlyTokenOwner(cabinetId) nonReentrant {
        CabinetConfig memory config = _cabinetConfigs[cabinetId];

        if (_cabinetItems[cabinetId].length + items.length > config.maxItems) {
            revert CabinetFull(cabinetId, config.maxItems);
        }

        for (uint256 i = 0; i < items.length; i++) {
            _validateGachaItem(items[i], cabinetId);
            _validateNoDuplicateItem(cabinetId, items[i].contractAddress, items[i].tokenIdOrAmount);

            // Transfer asset to contract
            _transferAssetToContract(items[i], msg.sender);

            // Add item to cabinet
            _cabinetItems[cabinetId].push(GachaItem({
                assetType: items[i].assetType,
                contractAddress: items[i].contractAddress,
                tokenIdOrAmount: items[i].tokenIdOrAmount,
                rarity: items[i].rarity,
                isActive: true,
                depositedAt: block.timestamp,
                depositor: msg.sender,
                withdrawableAfter: block.timestamp + 1 days
            }));

            emit ItemDeposited(
                cabinetId,
                _cabinetItems[cabinetId].length - 1,
                items[i].assetType,
                items[i].contractAddress,
                items[i].tokenIdOrAmount,
                items[i].rarity
            );
        }
    }

    /**
     * @dev Withdraw items from cabinet
     */
    function withdrawItems(
        uint256 cabinetId,
        uint256[] calldata itemIndices
    ) external cabinetExists(cabinetId) onlyTokenOwner(cabinetId) nonReentrant {
        for (uint256 i = 0; i < itemIndices.length; i++) {
            uint256 itemIndex = itemIndices[i];

            if (itemIndex >= _cabinetItems[cabinetId].length) {
                revert ItemNotFound(cabinetId, itemIndex);
            }

            GachaItem storage item = _cabinetItems[cabinetId][itemIndex];
            require(block.timestamp >= item.withdrawableAfter, "Item locked");

            // Transfer asset back to owner
            _transferAssetFromContract(item, msg.sender);

            // Remove item
            _removeItem(cabinetId, itemIndex);
        }
    }

    /**
     * @dev Toggle item active status
     */
    function toggleItemStatus(uint256 cabinetId, uint256 itemIndex)
        external
        cabinetExists(cabinetId)
        onlyTokenOwner(cabinetId)
    {
        if (itemIndex >= _cabinetItems[cabinetId].length) {
            revert ItemNotFound(cabinetId, itemIndex);
        }

        GachaItem storage item = _cabinetItems[cabinetId][itemIndex];
        item.isActive = !item.isActive;

        emit ItemStatusChanged(cabinetId, itemIndex, item.isActive);
    }

    // Game contract interface functions
    function updateCabinetStats(uint256 cabinetId, uint256 revenue, uint256 platformFee)
        external
        onlyGameContract
        cabinetExists(cabinetId)
    {
        _cabinetMetadata[cabinetId].totalPlays++;
        _cabinetMetadata[cabinetId].totalRevenue += revenue;
        _cabinetMetadata[cabinetId].lastPlayTime = block.timestamp;

        _cabinetRevenue[cabinetId] += (revenue - platformFee);
        _platformRevenue += platformFee;
    }

    function transferItemToPlayer(uint256 cabinetId, uint256 itemIndex, address player)
        external
        onlyGameContract
        cabinetExists(cabinetId)
    {
        if (itemIndex >= _cabinetItems[cabinetId].length) {
            revert ItemNotFound(cabinetId, itemIndex);
        }

        GachaItem storage item = _cabinetItems[cabinetId][itemIndex];
        require(item.isActive, "Item not active");

        // Transfer asset to player
        _transferAssetFromContract(item, player);

        // Remove item from cabinet
        _removeItem(cabinetId, itemIndex);
    }

    // View functions
    function getCabinetInfo(uint256 tokenId)
        external
        view
        cabinetExists(tokenId)
        returns (CabinetMetadata memory, CabinetConfig memory)
    {
        return (_cabinetMetadata[tokenId], _cabinetConfigs[tokenId]);
    }

    function getCabinetItems(uint256 cabinetId)
        external
        view
        cabinetExists(cabinetId)
        returns (GachaItem[] memory)
    {
        return _cabinetItems[cabinetId];
    }

    function getCabinetItem(uint256 cabinetId, uint256 itemIndex)
        external
        view
        cabinetExists(cabinetId)
        returns (GachaItem memory)
    {
        if (itemIndex >= _cabinetItems[cabinetId].length) {
            revert ItemNotFound(cabinetId, itemIndex);
        }
        return _cabinetItems[cabinetId][itemIndex];
    }

    function getCabinetItemCount(uint256 cabinetId)
        external
        view
        cabinetExists(cabinetId)
        returns (uint256)
    {
        return _cabinetItems[cabinetId].length;
    }

    function getActiveCabinetItems(uint256 cabinetId)
        external
        view
        cabinetExists(cabinetId)
        returns (GachaItem[] memory)
    {
        GachaItem[] memory allItems = _cabinetItems[cabinetId];
        uint256 activeCount = 0;

        for (uint256 i = 0; i < allItems.length; i++) {
            if (allItems[i].isActive) {
                activeCount++;
            }
        }

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

    function isActiveCabinet(uint256 cabinetId) external view returns (bool) {
        return _cabinetMetadata[cabinetId].isActive && !_cabinetConfigs[cabinetId].inMaintenance;
    }

    function getCabinetOwner(uint256 cabinetId) external view returns (address) {
        return ownerOf(cabinetId);
    }

    function getCabinetPlayPrice(uint256 cabinetId) external view returns (uint256) {
        return _cabinetConfigs[cabinetId].playPrice;
    }

    // Internal functions
    function _validateGachaItem(GachaItem calldata item, uint256 cabinetId) internal view {
        ValidationLib.validateContract(item.contractAddress, "asset contract");

        if (item.rarity == 0 || item.rarity > 4) {
            revert InvalidRarity(item.rarity);
        }

        if (item.assetType == AssetType.ERC721) {
            ValidationLib.validateERC721Ownership(
                IERC721(item.contractAddress),
                msg.sender,
                item.tokenIdOrAmount
            );
        } else if (item.assetType == AssetType.ERC20) {
            ValidationLib.validateERC20Balance(
                IERC20(item.contractAddress),
                msg.sender,
                item.tokenIdOrAmount
            );
        } else if (item.assetType == AssetType.ERC1155) {
            require(
                IERC1155(item.contractAddress).balanceOf(msg.sender, item.tokenIdOrAmount) > 0,
                "Insufficient ERC1155 balance"
            );
        } else {
            revert InvalidAssetType(item.assetType);
        }
    }

    function _validateNoDuplicateItem(
        uint256 cabinetId,
        address contractAddress,
        uint256 tokenIdOrAmount
    ) internal view {
        GachaItem[] memory items = _cabinetItems[cabinetId];
        for (uint256 i = 0; i < items.length; i++) {
            if (items[i].contractAddress == contractAddress &&
                items[i].tokenIdOrAmount == tokenIdOrAmount) {
                revert DuplicateItem(cabinetId, contractAddress, tokenIdOrAmount);
            }
        }
    }

    function _transferAssetToContract(GachaItem calldata item, address from) internal {
        if (item.assetType == AssetType.ERC721) {
            IERC721(item.contractAddress).transferFrom(from, address(this), item.tokenIdOrAmount);
        } else if (item.assetType == AssetType.ERC20) {
            IERC20(item.contractAddress).transferFrom(from, address(this), item.tokenIdOrAmount);
        } else if (item.assetType == AssetType.ERC1155) {
            IERC1155(item.contractAddress).safeTransferFrom(from, address(this), item.tokenIdOrAmount, 1, "");
        }
    }

    function _transferAssetFromContract(GachaItem storage item, address to) internal {
        if (item.assetType == AssetType.ERC721) {
            IERC721(item.contractAddress).transferFrom(address(this), to, item.tokenIdOrAmount);
        } else if (item.assetType == AssetType.ERC20) {
            IERC20(item.contractAddress).transfer(to, item.tokenIdOrAmount);
        } else if (item.assetType == AssetType.ERC1155) {
            IERC1155(item.contractAddress).safeTransferFrom(address(this), to, item.tokenIdOrAmount, 1, "");
        }
    }

    function _removeItem(uint256 cabinetId, uint256 itemIndex) internal {
        GachaItem[] storage items = _cabinetItems[cabinetId];

        items[itemIndex] = items[items.length - 1];
        items.pop();

        emit ItemWithdrawn(cabinetId, itemIndex, items[itemIndex].assetType);
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function totalCabinets() external view returns (uint256) {
        return _currentTokenId;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        cabinetExists(tokenId)
        returns (string memory)
    {
        CabinetMetadata memory metadata = _cabinetMetadata[tokenId];

        string memory svg = _generateSVG(tokenId);
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "TuuKeep Cabinet #',
                        tokenId.toString(),
                        '", "description": "A unique TuuKeep Gachapon Cabinet NFT", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(svg)),
                        '", "attributes": [',
                        '{"trait_type": "Cabinet Name", "value": "', metadata.name, '"},',
                        '{"trait_type": "Total Plays", "value": ', metadata.totalPlays.toString(), '},',
                        '{"trait_type": "Status", "value": "', metadata.isActive ? "Active" : "Inactive", '"}',
                        ']}'
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function _generateSVG(uint256 tokenId) internal view returns (string memory) {
        CabinetMetadata memory metadata = _cabinetMetadata[tokenId];
        return SVGGenerator.generateCabinetSVG(
            tokenId,
            metadata.name,
            metadata.isActive,
            metadata.totalPlays
        );
    }

    // Administrative functions
    function pause() external onlyRole(EMERGENCY_RESPONDER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(EMERGENCY_RESPONDER_ROLE) {
        _unpause();
    }

    function updatePlatformFeeRecipient(address newRecipient)
        external
        onlyRole(PLATFORM_ADMIN_ROLE)
    {
        ValidationLib.validateAddress(newRecipient, "fee recipient");
        platformFeeRecipient = newRecipient;
    }

    // Required overrides
    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function _update(address to, uint256 tokenId, address auth) internal override(ERC721, ERC721Enumerable) whenNotPaused returns (address) {
        address from = _ownerOf(tokenId);

        if (from != address(0) && to != address(0)) {
            _ownerCabinetCount[from]--;
            _ownerCabinetCount[to]++;
            _cabinetMetadata[tokenId].owner = to;
        }

        return super._update(to, tokenId, auth);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId) ||
               interfaceId == type(ITuuKeepCabinetCore).interfaceId;
    }
}