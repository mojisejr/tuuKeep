// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./Utils/Security/TuuKeepAccessControl.sol";
import "./Utils/Security/TuuKeepReentrancyGuard.sol";
import "./Utils/Security/ValidationLib.sol";
import "./interfaces/ITuuKeepCabinetCore.sol";

/**
 * @title TuuKeepCabinetItems
 * @dev Item management contract for TuuKeep Cabinet system
 * Handles depositing, withdrawing, and managing gacha items
 */
contract TuuKeepCabinetItems is AccessControl, Pausable, TuuKeepReentrancyGuard {
    // Access control roles
    bytes32 public constant PLATFORM_ADMIN_ROLE = keccak256("PLATFORM_ADMIN_ROLE");
    bytes32 public constant EMERGENCY_RESPONDER_ROLE = keccak256("EMERGENCY_RESPONDER_ROLE");
    bytes32 public constant GAME_CONTRACT_ROLE = keccak256("GAME_CONTRACT_ROLE");

    // Platform integration
    TuuKeepAccessControl public immutable accessControl;
    address public cabinetNFTContract;
    address public cabinetConfigContract;
    address public gameContract;

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

    // Storage
    mapping(uint256 => GachaItem[]) private _cabinetItems;

    // Custom errors
    error CabinetNotExists(uint256 tokenId);
    error NotCabinetOwner(uint256 tokenId, address caller);
    error CabinetFull(uint256 cabinetId, uint256 maxItems);
    error ItemNotFound(uint256 cabinetId, uint256 itemIndex);
    error InvalidAssetType(AssetType provided);
    error InvalidRarity(uint256 rarity);
    error DuplicateItem(uint256 cabinetId, address contractAddress, uint256 tokenIdOrAmount);
    error OnlyGameContract();

    modifier onlyGameContract() {
        if (msg.sender != gameContract) {
            revert OnlyGameContract();
        }
        _;
    }

    modifier cabinetExists(uint256 tokenId) {
        // This will be validated by calling the NFT contract
        _;
    }

    constructor(address _accessControl) {
        accessControl = TuuKeepAccessControl(_accessControl);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PLATFORM_ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_RESPONDER_ROLE, msg.sender);
    }

    /**
     * @dev Set contract addresses
     */
    function setContracts(
        address _cabinetNFTContract,
        address _cabinetConfigContract,
        address _gameContract
    ) external onlyRole(PLATFORM_ADMIN_ROLE) {
        ValidationLib.validateContract(_cabinetNFTContract, "cabinet NFT contract");
        ValidationLib.validateContract(_cabinetConfigContract, "cabinet config contract");
        ValidationLib.validateContract(_gameContract, "game contract");

        cabinetNFTContract = _cabinetNFTContract;
        cabinetConfigContract = _cabinetConfigContract;
        gameContract = _gameContract;

        _grantRole(GAME_CONTRACT_ROLE, _gameContract);
    }

    /**
     * @dev Deposit items into cabinet
     */
    function depositItems(
        uint256 cabinetId,
        GachaItem[] calldata items
    ) external cabinetExists(cabinetId) whenNotPaused nonReentrant {
        _validateCabinetOwner(cabinetId, msg.sender);

        // Get cabinet config
        uint256 maxItems = _getCabinetMaxItems(cabinetId);

        if (_cabinetItems[cabinetId].length + items.length > maxItems) {
            revert CabinetFull(cabinetId, maxItems);
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
    ) external cabinetExists(cabinetId) whenNotPaused nonReentrant {
        _validateCabinetOwner(cabinetId, msg.sender);

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
        whenNotPaused
    {
        _validateCabinetOwner(cabinetId, msg.sender);

        if (itemIndex >= _cabinetItems[cabinetId].length) {
            revert ItemNotFound(cabinetId, itemIndex);
        }

        GachaItem storage item = _cabinetItems[cabinetId][itemIndex];
        item.isActive = !item.isActive;

        emit ItemStatusChanged(cabinetId, itemIndex, item.isActive);
    }

    /**
     * @dev Transfer item to player (called by game contract)
     */
    function transferItemToPlayer(uint256 cabinetId, uint256 itemIndex, address player)
        external
        onlyGameContract
        cabinetExists(cabinetId)
        whenNotPaused
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

        emit ItemWon(cabinetId, itemIndex, player, item.assetType);
    }

    // View functions
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

    function _validateCabinetOwner(uint256 tokenId, address caller) internal view {
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

    function _getCabinetMaxItems(uint256 cabinetId) internal view returns (uint256) {
        (bool success, bytes memory data) = cabinetConfigContract.staticcall(
            abi.encodeWithSignature("getCabinetMaxItems(uint256)", cabinetId)
        );

        if (!success) {
            return ValidationLib.MAX_CABINET_ITEMS; // fallback to default
        }

        return abi.decode(data, (uint256));
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
    event ItemDeposited(
        uint256 indexed cabinetId,
        uint256 indexed itemIndex,
        AssetType assetType,
        address contractAddress,
        uint256 tokenIdOrAmount,
        uint256 rarity
    );
    event ItemWithdrawn(uint256 indexed cabinetId, uint256 indexed itemIndex, AssetType assetType);
    event ItemStatusChanged(uint256 indexed cabinetId, uint256 indexed itemIndex, bool active);
    event ItemWon(uint256 indexed cabinetId, uint256 indexed itemIndex, address indexed player, AssetType assetType);
}