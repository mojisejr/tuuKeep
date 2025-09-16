// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./Utils/Security/TuuKeepAccessControl.sol";
import "./Utils/Security/TuuKeepReentrancyGuard.sol";
import "./Utils/Security/ValidationLib.sol";
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
 *
 * Cabinet Economy:
 * - Cabinet owners can configure play prices and settings
 * - Cabinets generate revenue from player interactions
 * - Dynamic metadata reflects cabinet status and statistics
 * - SVG artwork generated on-chain for each cabinet
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

    // State variables
    mapping(uint256 => CabinetMetadata) public cabinetMetadata;
    mapping(uint256 => CabinetConfig) public cabinetConfig;

    uint256 private _tokenIdCounter;
    uint256 public constant MAX_CABINETS = 10000;
    uint256 public constant DEFAULT_PLATFORM_FEE_RATE = 500; // 5%
    uint256 public constant MAX_PLATFORM_FEE_RATE = 1000; // 10%
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

    // Custom errors
    error CabinetNotExists(uint256 tokenId);
    error NotCabinetOwner(uint256 tokenId, address caller);
    error CabinetInactive(uint256 tokenId);
    error InvalidConfiguration();
    error MaxCabinetsReached();
    error InvalidFeeRate(uint256 rate);

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
        require(to != address(0), "Cannot mint to zero address");
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
        require(config.playPrice > 0, "Play price must be positive");
        require(config.maxItems > 0 && config.maxItems <= 50, "Invalid max items");
        require(config.feeRecipient != address(0), "Invalid fee recipient");

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
     * @dev Generate dynamic SVG for cabinet NFT
     * @param tokenId Cabinet token ID
     * @return SVG string
     */
    function _generateSVG(uint256 tokenId)
        internal
        view
        returns (string memory)
    {
        CabinetMetadata memory metadata = cabinetMetadata[tokenId];

        // Color scheme based on cabinet status
        string memory primaryColor = metadata.isActive ? "#4CAF50" : "#9E9E9E";
        string memory accentColor = metadata.isActive ? "#81C784" : "#BDBDBD";

        return string(abi.encodePacked(
            '<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">',
            '<defs>',
            '<linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">',
            '<stop offset="0%" style="stop-color:', primaryColor, ';stop-opacity:1" />',
            '<stop offset="100%" style="stop-color:', accentColor, ';stop-opacity:1" />',
            '</linearGradient>',
            '</defs>',
            '<rect width="400" height="400" fill="url(#bg)"/>',
            '<rect x="50" y="80" width="300" height="240" fill="#2C2C2C" rx="20"/>',
            '<rect x="70" y="100" width="260" height="120" fill="#1A1A1A" rx="10"/>',
            '<circle cx="200" cy="160" r="30" fill="', primaryColor, '"/>',
            '<text x="200" y="280" text-anchor="middle" fill="white" font-family="Arial" font-size="16" font-weight="bold">',
            metadata.name,
            '</text>',
            '<text x="200" y="300" text-anchor="middle" fill="#CCCCCC" font-family="Arial" font-size="12">',
            'Cabinet #', tokenId.toString(),
            '</text>',
            '<text x="200" y="320" text-anchor="middle" fill="#CCCCCC" font-family="Arial" font-size="10">',
            metadata.isActive ? 'ACTIVE' : 'INACTIVE',
            '</text>',
            '<text x="200" y="350" text-anchor="middle" fill="#CCCCCC" font-family="Arial" font-size="10">',
            'Plays: ', metadata.totalPlays.toString(),
            '</text>',
            '</svg>'
        ));
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
        require(newRecipient != address(0), "Invalid recipient address");
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