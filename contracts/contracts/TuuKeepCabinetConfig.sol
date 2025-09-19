// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./Utils/Security/TuuKeepAccessControl.sol";
import "./Utils/Security/ValidationLib.sol";
import "./interfaces/ITuuKeepCabinetCore.sol";

/**
 * @title TuuKeepCabinetConfig
 * @dev Configuration management contract for TuuKeep Cabinet system
 * Handles pricing, settings, and operational parameters
 */
contract TuuKeepCabinetConfig is AccessControl, Pausable {
    // Access control roles
    bytes32 public constant PLATFORM_ADMIN_ROLE = keccak256("PLATFORM_ADMIN_ROLE");
    bytes32 public constant EMERGENCY_RESPONDER_ROLE = keccak256("EMERGENCY_RESPONDER_ROLE");
    bytes32 public constant CABINET_OWNER_ROLE = keccak256("CABINET_OWNER_ROLE");

    // Platform integration
    TuuKeepAccessControl public immutable accessControl;
    address public cabinetNFTContract;

    // Constants
    uint256 public constant DEFAULT_PLATFORM_FEE_RATE = 500; // 5%
    uint256 public constant MAX_PLATFORM_FEE_RATE = 2000; // 20%

    // Structs
    struct CabinetConfig {
        uint256 playPrice;
        bool requiresDeposit;
        uint256 maxItems;
        uint256 platformFeeRate;
        bool inMaintenance;
        address feeRecipient;
    }

    // Storage
    mapping(uint256 => CabinetConfig) private _cabinetConfigs;

    // Platform settings
    address public platformFeeRecipient;
    uint256 public platformFeeRate = DEFAULT_PLATFORM_FEE_RATE;

    // Custom errors
    error CabinetNotExists(uint256 tokenId);
    error NotCabinetOwner(uint256 tokenId, address caller);
    error InvalidConfiguration();
    error InvalidFeeRate(uint256 rate);
    error OnlyNFTContract();

    modifier onlyNFTContract() {
        if (msg.sender != cabinetNFTContract) {
            revert OnlyNFTContract();
        }
        _;
    }

    modifier cabinetExists(uint256 tokenId) {
        // This will be validated by calling the NFT contract
        _;
    }

    constructor(
        address _accessControl,
        address _platformFeeRecipient
    ) {
        accessControl = TuuKeepAccessControl(_accessControl);
        platformFeeRecipient = _platformFeeRecipient;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PLATFORM_ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_RESPONDER_ROLE, msg.sender);
    }

    /**
     * @dev Set the cabinet NFT contract address
     */
    function setCabinetNFTContract(address _cabinetNFTContract)
        external
        onlyRole(PLATFORM_ADMIN_ROLE)
    {
        ValidationLib.validateContract(_cabinetNFTContract, "cabinet NFT contract");
        cabinetNFTContract = _cabinetNFTContract;
    }

    /**
     * @dev Initialize cabinet configuration (called by NFT contract on mint)
     */
    function initializeCabinetConfig(
        uint256 tokenId,
        uint256 playPrice
    ) external onlyNFTContract {
        ValidationLib.validatePlayPrice(playPrice);

        _cabinetConfigs[tokenId] = CabinetConfig({
            playPrice: playPrice,
            requiresDeposit: true,
            maxItems: ValidationLib.MAX_CABINET_ITEMS,
            platformFeeRate: platformFeeRate,
            inMaintenance: false,
            feeRecipient: platformFeeRecipient
        });

        emit CabinetConfigured(tokenId, playPrice);
    }

    /**
     * @dev Configure cabinet settings (only cabinet owner can call)
     */
    function setCabinetConfig(
        uint256 tokenId,
        uint256 playPrice,
        uint256 maxItems,
        bool requiresDeposit
    ) external cabinetExists(tokenId) whenNotPaused {
        _validateCabinetOwner(tokenId, msg.sender);
        ValidationLib.validatePlayPrice(playPrice);
        ValidationLib.validateAmount(maxItems, 1, ValidationLib.MAX_CABINET_ITEMS, "max items");

        CabinetConfig storage config = _cabinetConfigs[tokenId];
        config.playPrice = playPrice;
        config.maxItems = maxItems;
        config.requiresDeposit = requiresDeposit;

        emit CabinetConfigured(tokenId, playPrice);
    }

    /**
     * @dev Update cabinet play price
     */
    function setPlayPrice(uint256 tokenId, uint256 newPrice)
        external
        cabinetExists(tokenId)
        whenNotPaused
    {
        _validateCabinetOwner(tokenId, msg.sender);
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
        whenNotPaused
    {
        _validateCabinetOwner(tokenId, msg.sender);
        _cabinetConfigs[tokenId].inMaintenance = inMaintenance;

        emit MaintenanceModeChanged(tokenId, inMaintenance);
    }

    /**
     * @dev Set maximum items for cabinet
     */
    function setMaxItems(uint256 tokenId, uint256 maxItems)
        external
        cabinetExists(tokenId)
        whenNotPaused
    {
        _validateCabinetOwner(tokenId, msg.sender);
        ValidationLib.validateAmount(maxItems, 1, ValidationLib.MAX_CABINET_ITEMS, "max items");

        _cabinetConfigs[tokenId].maxItems = maxItems;
        emit MaxItemsUpdated(tokenId, maxItems);
    }

    /**
     * @dev Set deposit requirement for cabinet
     */
    function setRequiresDeposit(uint256 tokenId, bool requiresDeposit)
        external
        cabinetExists(tokenId)
        whenNotPaused
    {
        _validateCabinetOwner(tokenId, msg.sender);
        _cabinetConfigs[tokenId].requiresDeposit = requiresDeposit;

        emit DepositRequirementChanged(tokenId, requiresDeposit);
    }

    // View functions
    function getCabinetConfig(uint256 tokenId)
        external
        view
        cabinetExists(tokenId)
        returns (CabinetConfig memory)
    {
        return _cabinetConfigs[tokenId];
    }

    function getCabinetPlayPrice(uint256 tokenId) external view returns (uint256) {
        return _cabinetConfigs[tokenId].playPrice;
    }

    function getCabinetMaxItems(uint256 tokenId) external view returns (uint256) {
        return _cabinetConfigs[tokenId].maxItems;
    }

    function isCabinetInMaintenance(uint256 tokenId) external view returns (bool) {
        return _cabinetConfigs[tokenId].inMaintenance;
    }

    function getCabinetRequiresDeposit(uint256 tokenId) external view returns (bool) {
        return _cabinetConfigs[tokenId].requiresDeposit;
    }

    function getPlatformFeeInfo() external view returns (address recipient, uint256 rate) {
        return (platformFeeRecipient, platformFeeRate);
    }

    // Platform administration functions
    function updatePlatformFeeRecipient(address newRecipient)
        external
        onlyRole(PLATFORM_ADMIN_ROLE)
    {
        ValidationLib.validateAddress(newRecipient, "fee recipient");
        platformFeeRecipient = newRecipient;
        emit PlatformFeeRecipientUpdated(newRecipient);
    }

    function updatePlatformFeeRate(uint256 newRate)
        external
        onlyRole(PLATFORM_ADMIN_ROLE)
    {
        if (newRate > MAX_PLATFORM_FEE_RATE) {
            revert InvalidFeeRate(newRate);
        }
        platformFeeRate = newRate;
        emit PlatformFeeRateUpdated(newRate);
    }

    // Internal functions
    function _validateCabinetOwner(uint256 tokenId, address caller) internal view {
        // Call the NFT contract to validate ownership
        // This is a simplified approach - in a real implementation you'd want to use interfaces
        (bool success, bytes memory data) = cabinetNFTContract.staticcall(
            abi.encodeWithSignature("getCabinetOwner(uint256)", tokenId)
        );

        if (!success) {
            revert CabinetNotExists(tokenId);
        }

        address owner = abi.decode(data, (address));
        if (owner != caller) {
            revert NotCabinetOwner(tokenId, caller);
        }
    }

    // Administrative functions
    function pause() external onlyRole(EMERGENCY_RESPONDER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(EMERGENCY_RESPONDER_ROLE) {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Events
    event CabinetConfigured(uint256 indexed tokenId, uint256 playPrice);
    event PriceUpdated(uint256 indexed tokenId, uint256 oldPrice, uint256 newPrice);
    event MaintenanceModeChanged(uint256 indexed tokenId, bool inMaintenance);
    event MaxItemsUpdated(uint256 indexed tokenId, uint256 maxItems);
    event DepositRequirementChanged(uint256 indexed tokenId, bool requiresDeposit);
    event PlatformFeeRecipientUpdated(address newRecipient);
    event PlatformFeeRateUpdated(uint256 newRate);
}