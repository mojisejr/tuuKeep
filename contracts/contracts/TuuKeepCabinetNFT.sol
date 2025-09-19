// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./Utils/Security/TuuKeepAccessControl.sol";
import "./Utils/Security/ValidationLib.sol";
import "./Utils/SVGGenerator.sol";
import "./interfaces/ITuuKeepCabinetCore.sol";

/**
 * @title TuuKeepCabinetNFT
 * @dev Basic ERC721 NFT contract for TuuKeep Cabinet system
 * Handles only minting, burning and basic metadata
 */
contract TuuKeepCabinetNFT is
    ERC721,
    ERC721Enumerable,
    AccessControl,
    Pausable
{
    using Strings for uint256;

    // Access control roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PLATFORM_ADMIN_ROLE = keccak256("PLATFORM_ADMIN_ROLE");
    bytes32 public constant EMERGENCY_RESPONDER_ROLE = keccak256("EMERGENCY_RESPONDER_ROLE");

    // Platform integration
    TuuKeepAccessControl public immutable accessControl;

    // Constants
    uint256 public constant MAX_CABINETS_PER_OWNER = 10;

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

    // Storage
    mapping(uint256 => CabinetMetadata) private _cabinetMetadata;
    mapping(address => uint256) private _ownerCabinetCount;

    // Current token ID counter
    uint256 private _currentTokenId = 0;

    // Custom errors
    error CabinetNotExists(uint256 tokenId);
    error NotCabinetOwner(uint256 tokenId, address caller);
    error MaxCabinetsReached();

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

    constructor(
        string memory name,
        string memory symbol,
        address _accessControl
    ) ERC721(name, symbol) {
        accessControl = TuuKeepAccessControl(_accessControl);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PLATFORM_ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_RESPONDER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    /**
     * @dev Mint a new cabinet NFT
     */
    function mintCabinet(
        address to,
        string calldata name
    ) external onlyRole(MINTER_ROLE) whenNotPaused returns (uint256) {
        ValidationLib.validateAddress(to, "recipient");
        ValidationLib.validateNonEmptyString(name, "cabinet name");

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

        _ownerCabinetCount[to]++;
        _safeMint(to, tokenId);

        emit CabinetMinted(tokenId, to, name);

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
     * @dev Update cabinet activity status
     */
    function setCabinetActive(uint256 tokenId, bool active)
        external
        cabinetExists(tokenId)
        onlyRole(PLATFORM_ADMIN_ROLE)
    {
        _cabinetMetadata[tokenId].isActive = active;
        emit CabinetStatusChanged(tokenId, active);
    }

    /**
     * @dev Update cabinet stats (called by game contract)
     */
    function updateCabinetStats(uint256 tokenId, uint256 revenue)
        external
        cabinetExists(tokenId)
        onlyRole(PLATFORM_ADMIN_ROLE)
    {
        _cabinetMetadata[tokenId].totalPlays++;
        _cabinetMetadata[tokenId].totalRevenue += revenue;
        _cabinetMetadata[tokenId].lastPlayTime = block.timestamp;
    }

    // View functions
    function getCabinetMetadata(uint256 tokenId)
        external
        view
        cabinetExists(tokenId)
        returns (CabinetMetadata memory)
    {
        return _cabinetMetadata[tokenId];
    }

    function getCabinetOwner(uint256 tokenId) external view returns (address) {
        return ownerOf(tokenId);
    }

    function isActiveCabinet(uint256 tokenId) external view returns (bool) {
        return _cabinetMetadata[tokenId].isActive;
    }

    function totalCabinets() external view returns (uint256) {
        return _currentTokenId;
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
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
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Events
    event CabinetMinted(uint256 indexed tokenId, address indexed owner, string name);
    event CabinetStatusChanged(uint256 indexed tokenId, bool active);
}