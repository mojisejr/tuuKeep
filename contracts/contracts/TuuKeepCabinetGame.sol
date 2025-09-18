// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./Utils/Security/TuuKeepReentrancyGuard.sol";
import "./Utils/Security/ValidationLib.sol";
import "./Utils/Randomness.sol";
import "./interfaces/ITuuKeepCabinetCore.sol";
import "./interfaces/ITuuKeepCabinetGame.sol";
import "./libraries/TuuKeepGameLogic.sol";
import "./TuuCoin.sol";

/**
 * @title TuuKeepCabinetGame
 * @dev Game contract for TuuKeep Cabinet gacha gameplay
 * Handles play mechanics, prize distribution, and revenue management
 */
contract TuuKeepCabinetGame is
    AccessControl,
    Pausable,
    TuuKeepReentrancyGuard,
    ITuuKeepCabinetGame
{
    // Access control roles
    bytes32 public constant PLATFORM_ADMIN_ROLE = keccak256("PLATFORM_ADMIN_ROLE");
    bytes32 public constant EMERGENCY_RESPONDER_ROLE = keccak256("EMERGENCY_RESPONDER_ROLE");

    // Platform contracts
    ITuuKeepCabinetCore public immutable cabinetCore;
    TuuCoin public immutable tuuCoin;
    Randomness public immutable randomness;

    // Revenue tracking
    mapping(uint256 => uint256) private _cabinetRevenue;
    uint256 private _platformRevenue;

    // Platform settings
    address public platformFeeRecipient;
    uint256 public constant DEFAULT_PLATFORM_FEE_RATE = 500; // 5%

    // Custom errors
    error CabinetNotExists(uint256 tokenId);
    error CabinetInactive(uint256 tokenId);
    error InsufficientPayment(uint256 required, uint256 provided);
    error InvalidTuuCoinAmount(uint256 amount, uint256 maxAllowed);
    error NoActiveItems(uint256 cabinetId);
    error TransferFailed(address to, uint256 amount);
    error NotCabinetOwner(uint256 tokenId, address caller);
    error RevenueDistributionFailed();

    constructor(
        address _cabinetCore,
        address _tuuCoin,
        address _randomness,
        address _platformFeeRecipient
    ) {
        ValidationLib.validateContract(_cabinetCore, "cabinet core");
        ValidationLib.validateContract(_tuuCoin, "TuuCoin");
        ValidationLib.validateContract(_randomness, "randomness");
        ValidationLib.validateAddress(_platformFeeRecipient, "platform fee recipient");

        cabinetCore = ITuuKeepCabinetCore(_cabinetCore);
        tuuCoin = TuuCoin(_tuuCoin);
        randomness = Randomness(_randomness);
        platformFeeRecipient = _platformFeeRecipient;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PLATFORM_ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_RESPONDER_ROLE, msg.sender);
    }

    /**
     * @dev Play gacha game with optional TuuCoin boost
     * @param cabinetId Cabinet to play
     * @param tuuCoinAmount Amount of TuuCoin to burn for bonus odds (optional)
     */
    function play(uint256 cabinetId, uint256 tuuCoinAmount)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        // Validate cabinet exists and is active
        if (!_cabinetExists(cabinetId)) {
            revert CabinetNotExists(cabinetId);
        }

        if (!cabinetCore.isActiveCabinet(cabinetId)) {
            revert CabinetInactive(cabinetId);
        }

        // Get cabinet info
        uint256 playPrice = cabinetCore.getCabinetPlayPrice(cabinetId);

        // Validate payment
        if (msg.value < playPrice) {
            revert InsufficientPayment(playPrice, msg.value);
        }

        // Get active items
        ITuuKeepCabinetCore.GachaItem[] memory activeItems = cabinetCore.getActiveCabinetItems(cabinetId);
        if (activeItems.length == 0) {
            revert NoActiveItems(cabinetId);
        }

        // Handle TuuCoin burning and bonus calculation
        uint256 bonusPercentage = 0;
        if (tuuCoinAmount > 0) {
            (bool isValid, uint256 maxAllowed) = TuuKeepGameLogic.validateTuuCoinAmount(tuuCoinAmount, playPrice);
            if (!isValid) {
                revert InvalidTuuCoinAmount(tuuCoinAmount, maxAllowed);
            }

            // Burn TuuCoin for bonus
            tuuCoin.burnForGachaPlay(msg.sender, tuuCoinAmount, cabinetId);
            bonusPercentage = TuuKeepGameLogic.calculateTuuCoinBonus(tuuCoinAmount, playPrice);
        }

        // Select prize using game logic
        (int256 selectedIndex, bool won) = TuuKeepGameLogic.selectPrizeItem(
            activeItems,
            randomness,
            msg.sender,
            cabinetId,
            bonusPercentage
        );

        // Distribute revenue
        (, ITuuKeepCabinetCore.CabinetConfig memory config) = cabinetCore.getCabinetInfo(cabinetId);
        (uint256 ownerAmount, uint256 platformAmount) = TuuKeepGameLogic.calculateRevenueDistribution(
            playPrice,
            config.platformFeeRate
        );

        // Update cabinet stats
        cabinetCore.updateCabinetStats(cabinetId, playPrice, platformAmount);

        // Update local revenue tracking
        _cabinetRevenue[cabinetId] += ownerAmount;
        _platformRevenue += platformAmount;

        // Mint TuuCoin reward (1:1 ratio with play amount)
        uint256 tuuCoinMintAmount = TuuKeepGameLogic.calculateTuuCoinMinting(playPrice);
        tuuCoin.mint(msg.sender, tuuCoinMintAmount);

        emit TuuCoinMinted(cabinetId, msg.sender, tuuCoinMintAmount);

        // Handle prize transfer if won
        if (won && selectedIndex >= 0) {
            _handlePrizeTransfer(cabinetId, uint256(selectedIndex), activeItems);
        }

        emit GachaPlayed(
            cabinetId,
            msg.sender,
            playPrice,
            tuuCoinAmount,
            won ? uint256(selectedIndex) : type(uint256).max,
            won
        );

        emit RevenueDistributed(cabinetId, ownerAmount, platformAmount, playPrice);

        // Return excess payment
        if (msg.value > playPrice) {
            _safeTransfer(msg.sender, msg.value - playPrice);
        }
    }

    /**
     * @dev Withdraw cabinet revenue (cabinet owner only)
     */
    function withdrawCabinetRevenue(uint256 cabinetId) external nonReentrant {
        if (!_cabinetExists(cabinetId)) {
            revert CabinetNotExists(cabinetId);
        }

        address owner = cabinetCore.getCabinetOwner(cabinetId);
        if (msg.sender != owner) {
            revert NotCabinetOwner(cabinetId, msg.sender);
        }

        uint256 amount = _cabinetRevenue[cabinetId];
        require(amount > 0, "No revenue to withdraw");

        _cabinetRevenue[cabinetId] = 0;
        _safeTransfer(owner, amount);

        emit RevenueWithdrawn(cabinetId, owner, amount);
    }

    /**
     * @dev Withdraw platform revenue (platform admin only)
     */
    function withdrawPlatformRevenue(uint256 amount) external onlyRole(PLATFORM_ADMIN_ROLE) nonReentrant {
        require(amount <= _platformRevenue, "Insufficient platform revenue");

        _platformRevenue -= amount;
        _safeTransfer(platformFeeRecipient, amount);
    }

    /**
     * @dev Batch withdraw revenue from multiple cabinets
     */
    function batchWithdrawRevenue(uint256[] calldata cabinetIds) external nonReentrant {
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < cabinetIds.length; i++) {
            uint256 cabinetId = cabinetIds[i];

            if (!_cabinetExists(cabinetId)) {
                continue; // Skip non-existent cabinets
            }

            address owner = cabinetCore.getCabinetOwner(cabinetId);
            if (msg.sender != owner) {
                continue; // Skip cabinets not owned by caller
            }

            uint256 amount = _cabinetRevenue[cabinetId];
            if (amount > 0) {
                _cabinetRevenue[cabinetId] = 0;
                totalAmount += amount;

                emit RevenueWithdrawn(cabinetId, owner, amount);
            }
        }

        if (totalAmount > 0) {
            _safeTransfer(msg.sender, totalAmount);
        }
    }

    // View functions
    function getCabinetRevenue(uint256 cabinetId) external view returns (uint256) {
        return _cabinetRevenue[cabinetId];
    }

    function getPlatformRevenue() external view returns (uint256) {
        return _platformRevenue;
    }

    function getCabinetAnalytics(uint256 cabinetId) external view returns (
        uint256 totalPlays,
        uint256 totalRevenue,
        uint256 averagePlayValue,
        uint256 lastPlayTime,
        uint256 itemCount,
        uint256 activeItemCount
    ) {
        return TuuKeepGameLogic.generateCabinetAnalytics(cabinetCore, cabinetId);
    }

    function getRevenueForecast(uint256 cabinetId, uint256 daysToForecast) external view returns (uint256 projectedRevenue) {
        if (!_cabinetExists(cabinetId)) {
            return 0;
        }

        (, , uint256 averagePlayValue, , ,) = TuuKeepGameLogic.generateCabinetAnalytics(cabinetCore, cabinetId);

        if (averagePlayValue == 0) {
            return 0;
        }

        // Simple projection based on current average (can be enhanced with more sophisticated algorithms)
        uint256 estimatedDailyPlays = 5; // Conservative estimate
        projectedRevenue = averagePlayValue * estimatedDailyPlays * daysToForecast;

        return projectedRevenue;
    }

    // Internal functions
    function _handlePrizeTransfer(
        uint256 cabinetId,
        uint256 prizeIndex,
        ITuuKeepCabinetCore.GachaItem[] memory activeItems
    ) internal {
        // Find the actual item index in the cabinet
        ITuuKeepCabinetCore.GachaItem[] memory allItems = cabinetCore.getCabinetItems(cabinetId);
        uint256 actualItemIndex = 0;
        uint256 activeCount = 0;

        for (uint256 i = 0; i < allItems.length; i++) {
            if (allItems[i].isActive) {
                if (activeCount == prizeIndex) {
                    actualItemIndex = i;
                    break;
                }
                activeCount++;
            }
        }

        // Transfer prize to player
        cabinetCore.transferItemToPlayer(cabinetId, actualItemIndex, msg.sender);

        emit PrizeWon(
            cabinetId,
            msg.sender,
            actualItemIndex,
            activeItems[prizeIndex].contractAddress,
            activeItems[prizeIndex].tokenIdOrAmount
        );
    }

    function _cabinetExists(uint256 cabinetId) internal view returns (bool) {
        try cabinetCore.ownerOf(cabinetId) returns (address) {
            return true;
        } catch {
            return false;
        }
    }

    function _safeTransfer(address to, uint256 amount) internal {
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) {
            revert TransferFailed(to, amount);
        }
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

    // Events for revenue withdrawal (not in interface but needed for implementation)
    event RevenueWithdrawn(uint256 indexed cabinetId, address indexed owner, uint256 amount);

    // Receive function to accept ETH
    receive() external payable {}

    // Required overrides
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return super.supportsInterface(interfaceId) ||
               interfaceId == type(ITuuKeepCabinetGame).interfaceId;
    }
}