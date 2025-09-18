// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../Utils/Randomness.sol";
import "../interfaces/ITuuKeepCabinetCore.sol";

/**
 * @title TuuKeepGameLogic
 * @dev Library containing complex game logic functions extracted from TuuKeepCabinet
 */
library TuuKeepGameLogic {

    // Events (re-declared for library usage)
    event PrizeWon(
        uint256 indexed cabinetId,
        address indexed player,
        uint256 indexed itemIndex,
        address contractAddress,
        uint256 tokenIdOrAmount
    );

    event RevenueDistributed(
        uint256 indexed cabinetId,
        uint256 ownerAmount,
        uint256 platformAmount,
        uint256 totalAmount
    );

    /**
     * @dev Get active items from a cabinet
     * @param core TuuKeepCabinetCore contract instance
     * @param cabinetId Cabinet ID
     * @return activeItems Array of active GachaItem structs
     */
    function getActiveItems(
        ITuuKeepCabinetCore core,
        uint256 cabinetId
    ) external view returns (ITuuKeepCabinetCore.GachaItem[] memory activeItems) {
        ITuuKeepCabinetCore.GachaItem[] memory allItems = core.getCabinetItems(cabinetId);

        // Count active items first
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allItems.length; i++) {
            if (allItems[i].isActive) {
                activeCount++;
            }
        }

        // Create array of active items
        activeItems = new ITuuKeepCabinetCore.GachaItem[](activeCount);
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
     * @dev Select a prize item based on rarity weights and randomness
     * @param activeItems Array of active items
     * @param randomnessContract Randomness contract instance
     * @param player Player address
     * @param cabinetId Cabinet ID
     * @param tuuCoinBonus Bonus percentage from TuuCoin (0-20)
     * @return selectedIndex Index of selected item (-1 if no prize)
     * @return won Whether player won a prize
     */
    function selectPrizeItem(
        ITuuKeepCabinetCore.GachaItem[] memory activeItems,
        Randomness randomnessContract,
        address player,
        uint256 cabinetId,
        uint256 tuuCoinBonus
    ) external returns (int256 selectedIndex, bool won) {
        if (activeItems.length == 0) {
            return (-1, false);
        }

        // Calculate total weight based on rarity and TuuCoin bonus
        uint256 totalWeight = 0;
        uint256[] memory weights = new uint256[](activeItems.length);

        for (uint256 i = 0; i < activeItems.length; i++) {
            // Base weight calculation: higher rarity = lower base chance
            uint256 baseWeight;
            if (activeItems[i].rarity == 1) {
                baseWeight = 100; // Common: 10% base chance
            } else if (activeItems[i].rarity == 2) {
                baseWeight = 50;  // Rare: 5% base chance
            } else if (activeItems[i].rarity == 3) {
                baseWeight = 20;  // Epic: 2% base chance
            } else if (activeItems[i].rarity == 4) {
                baseWeight = 5;   // Legendary: 0.5% base chance
            } else {
                baseWeight = 10;  // Default: 1% base chance
            }

            // Apply TuuCoin bonus (0-20% additional chance)
            weights[i] = baseWeight + (baseWeight * tuuCoinBonus / 100);
            totalWeight += weights[i];
        }

        // Add "no prize" weight (approximately 50% chance of no prize)
        uint256 noPrizeWeight = totalWeight;
        totalWeight += noPrizeWeight;

        // Generate random number
        uint256 requestId = uint256(keccak256(abi.encodePacked(player, cabinetId, block.timestamp, block.prevrandao)));
        uint256 randomValue = randomnessContract.generateRandomNumber(requestId) % totalWeight;

        // Determine if player wins and which item
        if (randomValue >= totalWeight - noPrizeWeight) {
            // No prize
            return (-1, false);
        }

        // Find winning item
        uint256 currentWeight = 0;
        for (uint256 i = 0; i < activeItems.length; i++) {
            currentWeight += weights[i];
            if (randomValue < currentWeight) {
                return (int256(i), true);
            }
        }

        // Fallback: no prize
        return (-1, false);
    }

    /**
     * @dev Calculate revenue distribution between owner and platform
     * @param totalAmount Total payment amount
     * @param platformFeeRate Platform fee rate in basis points (0-10000)
     * @return ownerAmount Amount for cabinet owner
     * @return platformAmount Amount for platform
     */
    function calculateRevenueDistribution(
        uint256 totalAmount,
        uint256 platformFeeRate
    ) external pure returns (uint256 ownerAmount, uint256 platformAmount) {
        require(platformFeeRate <= 10000, "TuuKeepGameLogic: Invalid fee rate");

        platformAmount = (totalAmount * platformFeeRate) / 10000;
        ownerAmount = totalAmount - platformAmount;

        return (ownerAmount, platformAmount);
    }

    /**
     * @dev Calculate TuuCoin bonus percentage based on amount and play price
     * @param tuuCoinAmount Amount of TuuCoin to burn
     * @param playPrice Cabinet play price
     * @return bonusPercentage Bonus percentage (0-20)
     */
    function calculateTuuCoinBonus(
        uint256 tuuCoinAmount,
        uint256 playPrice
    ) external pure returns (uint256 bonusPercentage) {
        if (tuuCoinAmount == 0) {
            return 0;
        }

        // Maximum 20% of play price can be used for bonus
        uint256 maxBurnAmount = (playPrice * 20) / 100;
        if (tuuCoinAmount > maxBurnAmount) {
            tuuCoinAmount = maxBurnAmount;
        }

        // Each 1% of play price burned = 1% bonus (max 20%)
        bonusPercentage = (tuuCoinAmount * 100) / playPrice;

        return bonusPercentage;
    }

    /**
     * @dev Validate TuuCoin burn amount
     * @param tuuCoinAmount Amount to burn
     * @param playPrice Cabinet play price
     * @return isValid Whether the amount is valid
     * @return maxAllowed Maximum allowed burn amount
     */
    function validateTuuCoinAmount(
        uint256 tuuCoinAmount,
        uint256 playPrice
    ) external pure returns (bool isValid, uint256 maxAllowed) {
        maxAllowed = (playPrice * 20) / 100; // 20% of play price
        isValid = tuuCoinAmount <= maxAllowed;

        return (isValid, maxAllowed);
    }

    /**
     * @dev Calculate TuuCoin minting amount based on play amount
     * @param playAmount Amount paid for playing
     * @return mintAmount Amount of TuuCoin to mint (1:1 ratio)
     */
    function calculateTuuCoinMinting(
        uint256 playAmount
    ) external pure returns (uint256 mintAmount) {
        // 1:1 ratio: 1 wei spent = 1 TuuCoin minted
        return playAmount;
    }

    /**
     * @dev Generate analytics for a cabinet
     * @param core TuuKeepCabinetCore contract instance
     * @param cabinetId Cabinet ID
     * @return totalPlays Total number of plays
     * @return totalRevenue Total revenue generated
     * @return averagePlayValue Average value per play
     * @return lastPlayTime Timestamp of last play
     * @return itemCount Total number of items
     * @return activeItemCount Number of active items
     */
    function generateCabinetAnalytics(
        ITuuKeepCabinetCore core,
        uint256 cabinetId
    ) external view returns (
        uint256 totalPlays,
        uint256 totalRevenue,
        uint256 averagePlayValue,
        uint256 lastPlayTime,
        uint256 itemCount,
        uint256 activeItemCount
    ) {
        (ITuuKeepCabinetCore.CabinetMetadata memory metadata,) = core.getCabinetInfo(cabinetId);

        totalPlays = metadata.totalPlays;
        totalRevenue = metadata.totalRevenue;
        lastPlayTime = metadata.lastPlayTime;

        // Calculate average play value
        if (totalPlays > 0) {
            averagePlayValue = totalRevenue / totalPlays;
        } else {
            averagePlayValue = 0;
        }

        // Count items
        ITuuKeepCabinetCore.GachaItem[] memory items = core.getCabinetItems(cabinetId);
        itemCount = items.length;

        activeItemCount = 0;
        for (uint256 i = 0; i < items.length; i++) {
            if (items[i].isActive) {
                activeItemCount++;
            }
        }

        return (totalPlays, totalRevenue, averagePlayValue, lastPlayTime, itemCount, activeItemCount);
    }
}