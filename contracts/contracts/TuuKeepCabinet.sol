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
import "./Utils/Randomness.sol";
import "./Utils/TuuKeepErrors.sol";
import "./TuuCoin.sol";

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
    Randomness public immutable randomness;

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

    // Gameplay state
    mapping(uint256 => uint256) public cabinetRevenue;          // Cabinet ID => accumulated revenue
    mapping(address => uint256) public platformRevenue;         // Platform accumulated revenue by token
    uint256 private _playRequestCounter;                        // Counter for randomness requests

    uint256 private _tokenIdCounter;
    uint256 public constant MAX_CABINETS = 10000;
    uint256 public constant DEFAULT_PLATFORM_FEE_RATE = 500;
    uint256 public constant MAX_PLATFORM_FEE_RATE = 1000;
    address public platformFeeRecipient;

    // Events
    event CabinetMinted(uint256 indexed tokenId, address indexed owner, string name);
    event CabinetConfigured(uint256 indexed tokenId, uint256 playPrice);
    event CabinetStatusChanged(uint256 indexed tokenId, bool isActive);
    event PriceUpdated(uint256 indexed tokenId, uint256 oldPrice, uint256 newPrice);
    event RevenueWithdrawn(uint256 indexed tokenId, address indexed owner, uint256 amount);

    event ItemDeposited(uint256 indexed cabinetId, uint256 indexed itemIndex, AssetType assetType, address contractAddress, uint256 tokenIdOrAmount, uint256 rarity);
    event ItemWithdrawn(uint256 indexed cabinetId, uint256 indexed itemIndex, AssetType assetType);
    event ItemStatusChanged(uint256 indexed cabinetId, uint256 indexed itemIndex, bool isActive);

    event GachaPlayed(
        uint256 indexed cabinetId,
        address indexed player,
        uint256 playPrice,
        uint256 tuuCoinAmount,
        bool wonPrize,
        uint256 itemIndex,
        uint256 timestamp
    );

    event PrizeWon(
        uint256 indexed cabinetId,
        address indexed player,
        uint256 indexed itemIndex,
        AssetType assetType,
        address contractAddress,
        uint256 tokenIdOrAmount,
        uint256 rarity,
        uint256 timestamp
    );

    event RevenueDistributed(
        uint256 indexed cabinetId,
        address indexed cabinetOwner,
        uint256 cabinetRevenue,
        uint256 platformRevenue,
        uint256 timestamp
    );

    event TuuCoinMinted(
        uint256 indexed cabinetId,
        address indexed player,
        uint256 amount,
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
    error InsufficientPayment(uint256 required, uint256 provided);
    error NoActiveItems(uint256 cabinetId);
    error InvalidTuuCoinAmount(uint256 amount, uint256 maxAllowed);
    error TransferFailed(address to, uint256 amount);

    constructor(
        address _accessControl,
        address _tuuCoin,
        address _randomness,
        address _platformFeeRecipient
    )
        ERC721("TuuKeep Cabinet", "CABINET")
        TuuKeepReentrancyGuard()
    {
        if (_accessControl == address(0) || _tuuCoin == address(0) || _randomness == address(0) || _platformFeeRecipient == address(0)) revert TuuKeepErrors.InvalidAddress();

        accessControl = TuuKeepAccessControl(_accessControl);
        tuuCoin = TuuCoin(_tuuCoin);
        randomness = Randomness(_randomness);
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

        emit CabinetMinted(tokenId, to, cabinetName);

        return tokenId;
    }

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

        cabinetMetadata[tokenId].name = newName;

        emit CabinetConfigured(tokenId, cabinetConfig[tokenId].playPrice);
    }

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

        emit CabinetConfigured(tokenId, config.playPrice);
    }

    function activateCabinet(uint256 tokenId)
        external
        onlyTokenOwner(tokenId)
        cabinetExists(tokenId)
        nonReentrant
    {
        cabinetMetadata[tokenId].isActive = true;

        // Update status in TuuCoin contract
        tuuCoin.updateCabinetStatus(tokenId, true);

        emit CabinetStatusChanged(tokenId, true);
    }

    function deactivateCabinet(uint256 tokenId)
        external
        onlyTokenOwner(tokenId)
        cabinetExists(tokenId)
        nonReentrant
    {
        cabinetMetadata[tokenId].isActive = false;

        // Update status in TuuCoin contract
        tuuCoin.updateCabinetStatus(tokenId, false);

        emit CabinetStatusChanged(tokenId, false);
    }

    function setPrice(uint256 tokenId, uint256 newPrice)
        external
        onlyTokenOwner(tokenId)
        cabinetExists(tokenId)
        nonReentrant
    {
        ValidationLib.validatePlayPrice(newPrice);

        uint256 oldPrice = cabinetConfig[tokenId].playPrice;
        cabinetConfig[tokenId].playPrice = newPrice;

        emit PriceUpdated(tokenId, oldPrice, newPrice);
    }

    function setMaintenanceMode(uint256 tokenId, bool inMaintenance)
        external
        onlyTokenOwner(tokenId)
        cabinetExists(tokenId)
        nonReentrant
    {
        bool oldStatus = cabinetMetadata[tokenId].isActive;

        // Maintenance mode overrides active status
        if (inMaintenance) {
            cabinetMetadata[tokenId].isActive = false;
        }

        emit CabinetStatusChanged(tokenId, !inMaintenance);

        if (oldStatus != cabinetMetadata[tokenId].isActive) {
            tuuCoin.updateCabinetStatus(tokenId, cabinetMetadata[tokenId].isActive);
            emit CabinetStatusChanged(tokenId, cabinetMetadata[tokenId].isActive);
        }
    }

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

            emit ItemDeposited(cabinetId, itemIndex, item.assetType, item.contractAddress, item.tokenIdOrAmount, item.rarity);
        }

        // Update item count
        itemCount[cabinetId] = newCount;
    }

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

            emit ItemWithdrawn(cabinetId, itemIndex, item.assetType);

            // Remove item from storage
            _removeItem(cabinetId, itemIndex);
        }

        // Update item count
        itemCount[cabinetId] = cabinetItems[cabinetId].length;
    }

    function play(uint256 cabinetId, uint256 tuuCoinAmount)
        external
        payable
        cabinetExists(cabinetId)
        onlyActiveCabinet(cabinetId)
        nonReentrant
    {
        CabinetConfig memory config = cabinetConfig[cabinetId];

        // Validate payment
        if (msg.value < config.playPrice) {
            revert InsufficientPayment(config.playPrice, msg.value);
        }

        // Check if cabinet has active items
        GachaItem[] memory activeItems = _getActiveItems(cabinetId);
        if (activeItems.length == 0) {
            revert NoActiveItems(cabinetId);
        }

        // Validate TuuCoin amount (max 20% of play price)
        uint256 maxTuuCoinAmount = (config.playPrice * 20) / 100;
        if (tuuCoinAmount > maxTuuCoinAmount) {
            revert InvalidTuuCoinAmount(tuuCoinAmount, maxTuuCoinAmount);
        }

        // Burn TuuCoin if provided for odds improvement
        if (tuuCoinAmount > 0) {
            tuuCoin.burnFrom(msg.sender, tuuCoinAmount);
        }

        // Generate random number for item selection
        uint256 requestId = ++_playRequestCounter;
        uint256 randomNumber = randomness.generateRandomNumber(requestId);

        // Calculate odds and select item
        (bool wonPrize, uint256 selectedItemIndex) = _selectPrizeItem(
            cabinetId,
            activeItems,
            randomNumber,
            tuuCoinAmount,
            config.playPrice
        );

        // Distribute revenue
        _distributeRevenue(cabinetId, config, msg.value);

        if (wonPrize) {
            // Transfer prize to player
            _transferPrizeToPlayer(cabinetId, selectedItemIndex, msg.sender);

            emit PrizeWon(
                cabinetId,
                msg.sender,
                selectedItemIndex,
                cabinetItems[cabinetId][selectedItemIndex].assetType,
                cabinetItems[cabinetId][selectedItemIndex].contractAddress,
                cabinetItems[cabinetId][selectedItemIndex].tokenIdOrAmount,
                cabinetItems[cabinetId][selectedItemIndex].rarity,
                block.timestamp
            );
        } else {
            // Mint TuuCoin as consolation prize
            uint256 mintAmount = config.playPrice / 10; // 10% of play price as TuuCoin
            tuuCoin.mint(msg.sender, mintAmount);

            // TuuCoin minting handled by TuuCoin contract
        }

        // Update cabinet statistics
        updateCabinetStats(cabinetId, 1, msg.value);

        emit GachaPlayed(
            cabinetId,
            msg.sender,
            config.playPrice,
            tuuCoinAmount,
            wonPrize,
            wonPrize ? selectedItemIndex : type(uint256).max,
            block.timestamp
        );

        // Refund excess payment
        if (msg.value > config.playPrice) {
            _safeTransfer(msg.sender, msg.value - config.playPrice);
        }
    }

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

    }

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
            if (!success) revert TuuKeepErrors.TransferFailed();
        }
    }

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
            if (!success) revert TuuKeepErrors.TransferFailed();
        }
    }

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

    function _getActiveItems(uint256 cabinetId) internal view returns (GachaItem[] memory) {
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

    function _selectPrizeItem(
        uint256 cabinetId,
        GachaItem[] memory activeItems,
        uint256 randomNumber,
        uint256 tuuCoinAmount,
        uint256 playPrice
    ) internal view returns (bool wonPrize, uint256 selectedItemIndex) {
        if (activeItems.length == 0) {
            return (false, 0);
        }

        // Calculate total weight based on rarity (higher rarity = lower weight = rarer)
        uint256 totalWeight = 0;
        uint256[] memory weights = new uint256[](activeItems.length);

        for (uint256 i = 0; i < activeItems.length; i++) {
            // Rarity 1 = common (weight 100), Rarity 5 = legendary (weight 1)
            weights[i] = 101 - (activeItems[i].rarity * 20);
            totalWeight += weights[i];
        }

        // Calculate base win probability (50% base chance)
        uint256 baseWinProbability = 5000; // 50% in basis points

        // Apply TuuCoin odds improvement (up to 20% improvement)
        uint256 oddsImprovement = 0;
        if (tuuCoinAmount > 0 && playPrice > 0) {
            // Calculate improvement: (tuuCoinAmount / (playPrice * 0.2)) * 2000
            // Max 2000 basis points (20%) improvement
            oddsImprovement = (tuuCoinAmount * 2000 * 100) / (playPrice * 20);
            if (oddsImprovement > 2000) {
                oddsImprovement = 2000;
            }
        }

        uint256 finalWinProbability = baseWinProbability + oddsImprovement;
        if (finalWinProbability > 10000) {
            finalWinProbability = 10000; // Cap at 100%
        }

        // Check if player wins any prize
        uint256 winRoll = randomNumber % 10000;
        if (winRoll >= finalWinProbability) {
            return (false, 0); // No prize
        }

        // Select specific item based on weighted probability
        uint256 itemRoll = randomNumber % totalWeight;
        uint256 cumulativeWeight = 0;

        for (uint256 i = 0; i < activeItems.length; i++) {
            cumulativeWeight += weights[i];
            if (itemRoll < cumulativeWeight) {
                // Find the actual index in the cabinet's item array
                for (uint256 j = 0; j < cabinetItems[cabinetId].length; j++) {
                    if (cabinetItems[cabinetId][j].contractAddress == activeItems[i].contractAddress &&
                        cabinetItems[cabinetId][j].tokenIdOrAmount == activeItems[i].tokenIdOrAmount &&
                        cabinetItems[cabinetId][j].isActive) {
                        return (true, j);
                    }
                }
            }
        }

        // Fallback - should not reach here
        return (false, 0);
    }

    function _distributeRevenue(
        uint256 cabinetId,
        CabinetConfig memory config,
        uint256 amount
    ) internal {
        uint256 platformFee = (amount * config.platformFeeRate) / 10000;
        uint256 cabinetOwnerRevenue = amount - platformFee;

        // Add to cabinet owner's revenue
        cabinetRevenue[cabinetId] += cabinetOwnerRevenue;

        // Add to platform revenue
        platformRevenue[address(0)] += platformFee; // ETH revenue

        emit RevenueDistributed(
            cabinetId,
            ownerOf(cabinetId),
            cabinetOwnerRevenue,
            platformFee,
            block.timestamp
        );
    }

    function _transferPrizeToPlayer(
        uint256 cabinetId,
        uint256 itemIndex,
        address player
    ) internal {
        if (itemIndex >= cabinetItems[cabinetId].length) revert TuuKeepErrors.InvalidIndex();
        if (!itemExists[cabinetId][itemIndex]) revert TuuKeepErrors.AssetNotFound();

        GachaItem storage item = cabinetItems[cabinetId][itemIndex];

        // Transfer asset to player
        _transferAssetFromContract(item, player);

        // Remove item from cabinet
        _removeItem(cabinetId, itemIndex);

        // Update item count
        itemCount[cabinetId] = cabinetItems[cabinetId].length;
    }

    function _safeTransfer(address to, uint256 amount) internal {
        if (amount > 0) {
            (bool success, ) = payable(to).call{value: amount}("");
            if (!success) {
                revert TransferFailed(to, amount);
            }
        }
    }

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

    function _registerCabinetWithTuuCoin(uint256 tokenId) internal {
        try tuuCoin.registerCabinet(tokenId, ownerOf(tokenId)) {
            // Cabinet registration successful
        } catch {
            // Registration failed, but don't revert the mint
            // This allows the contract to work even if TuuCoin registration fails
        }
    }

    function getCabinetInfo(uint256 tokenId)
        external
        view
        cabinetExists(tokenId)
        returns (CabinetMetadata memory metadata, CabinetConfig memory config)
    {
        return (cabinetMetadata[tokenId], cabinetConfig[tokenId]);
    }

    function getCabinetItems(uint256 cabinetId)
        external
        view
        cabinetExists(cabinetId)
        returns (GachaItem[] memory)
    {
        return cabinetItems[cabinetId];
    }

    function getCabinetItem(uint256 cabinetId, uint256 itemIndex)
        external
        view
        cabinetExists(cabinetId)
        returns (GachaItem memory)
    {
        require(itemIndex < cabinetItems[cabinetId].length, "Item index out of bounds");
        if (!itemExists[cabinetId][itemIndex]) revert TuuKeepErrors.AssetNotFound();
        return cabinetItems[cabinetId][itemIndex];
    }

    function getCabinetItemCount(uint256 cabinetId)
        external
        view
        cabinetExists(cabinetId)
        returns (uint256)
    {
        return itemCount[cabinetId];
    }

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

    function toggleItemStatus(uint256 cabinetId, uint256 itemIndex)
        external
        onlyTokenOwner(cabinetId)
        cabinetExists(cabinetId)
        nonReentrant
    {
        require(itemIndex < cabinetItems[cabinetId].length, "Item index out of bounds");
        if (!itemExists[cabinetId][itemIndex]) revert TuuKeepErrors.AssetNotFound();

        GachaItem storage item = cabinetItems[cabinetId][itemIndex];
        item.isActive = !item.isActive;

        if (item.isActive) {
            emit ItemStatusChanged(cabinetId, itemIndex, true);
        } else {
            emit ItemStatusChanged(cabinetId, itemIndex, false);
        }
    }

    function withdrawCabinetRevenue(uint256 cabinetId)
        external
        onlyTokenOwner(cabinetId)
        cabinetExists(cabinetId)
        nonReentrant
    {
        uint256 revenue = cabinetRevenue[cabinetId];
        if (revenue == 0) revert TuuKeepErrors.InvalidAmount();

        cabinetRevenue[cabinetId] = 0;
        _safeTransfer(msg.sender, revenue);
    }

    function withdrawPlatformRevenue(uint256 amount)
        external
        onlyRole(PLATFORM_ADMIN_ROLE)
        nonReentrant
    {
        if (amount == 0) revert TuuKeepErrors.InvalidAmount();
        if (platformRevenue[address(0)] < amount) revert TuuKeepErrors.InsufficientPayment();

        platformRevenue[address(0)] -= amount;
        _safeTransfer(msg.sender, amount);
    }

    function getCabinetRevenue(uint256 cabinetId)
        external
        view
        cabinetExists(cabinetId)
        returns (uint256)
    {
        return cabinetRevenue[cabinetId];
    }

    function getPlatformRevenue() external view returns (uint256) {
        return platformRevenue[address(0)];
    }

    function getCabinetAnalytics(uint256 cabinetId)
        external
        view
        cabinetExists(cabinetId)
        returns (uint256 totalRevenue, uint256 totalPlays, uint256 averageRevenue)
    {
        CabinetMetadata memory metadata = cabinetMetadata[cabinetId];
        totalRevenue = metadata.totalRevenue;
        totalPlays = metadata.totalPlays;

        if (totalPlays > 0) {
            averageRevenue = totalRevenue / totalPlays;
        } else {
            averageRevenue = 0;
        }
    }

    function batchWithdrawRevenue(uint256[] calldata cabinetIds)
        external
        nonReentrant
    {
        if (cabinetIds.length == 0) revert TuuKeepErrors.InvalidAmount();
        if (cabinetIds.length > 10) revert TuuKeepErrors.InvalidAmount(); // Gas limit protection

        uint256 totalWithdrawal = 0;

        for (uint256 i = 0; i < cabinetIds.length; i++) {
            uint256 cabinetId = cabinetIds[i];

            // Verify ownership
            require(ownerOf(cabinetId) == msg.sender, "Not cabinet owner");

            uint256 revenue = cabinetRevenue[cabinetId];
            if (revenue > 0) {
                cabinetRevenue[cabinetId] = 0;
                totalWithdrawal += revenue;
            }
        }

        if (totalWithdrawal == 0) revert TuuKeepErrors.InvalidAmount();
        _safeTransfer(msg.sender, totalWithdrawal);
    }

    function getRevenueForecast(uint256 cabinetId, uint256 daysToForecast)
        external
        view
        cabinetExists(cabinetId)
        returns (uint256 estimatedRevenue)
    {
        if (daysToForecast == 0 || daysToForecast > 365) revert TuuKeepErrors.InvalidAmount();

        CabinetMetadata memory metadata = cabinetMetadata[cabinetId];

        if (metadata.totalPlays == 0) {
            return 0;
        }

        // Simple forecast based on average revenue per play
        uint256 averageRevenue = metadata.totalRevenue / metadata.totalPlays;

        // Assume consistent play rate (simplified forecasting)
        // In a real implementation, this could use more sophisticated time-series analysis
        uint256 estimatedPlaysPerDay = metadata.totalPlays / 30; // Assume 30-day history

        estimatedRevenue = averageRevenue * estimatedPlaysPerDay * daysToForecast;
    }

    function totalCabinets() external view returns (uint256) {
        return _tokenIdCounter;
    }

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
        if (newRecipient == address(0)) revert TuuKeepErrors.InvalidAddress();
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