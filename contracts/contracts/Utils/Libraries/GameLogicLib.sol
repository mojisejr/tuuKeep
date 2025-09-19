// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title GameLogicLib
 * @dev Library for game mechanics and probability calculations
 */
library GameLogicLib {

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

    // Rarity weights for probability calculations
    uint256 public constant COMMON_WEIGHT = 5000;    // 50%
    uint256 public constant UNCOMMON_WEIGHT = 3000;  // 30%
    uint256 public constant RARE_WEIGHT = 1500;     // 15%
    uint256 public constant LEGENDARY_WEIGHT = 500;  // 5%
    uint256 public constant TOTAL_WEIGHT = 10000;   // 100%

    // Custom errors
    error InvalidProbabilityInput(string reason);
    error NoEligibleItems(uint256 cabinetId);
    error InvalidRandomSeed(uint256 seed);

    /**
     * @dev Calculate rarity probability based on item rarity and user burn history
     */
    function calculateItemProbability(
        uint256 rarity,
        uint256 userBurnedAmount,
        uint256 baseOddsImprovement
    ) internal pure returns (uint256 probability) {
        uint256 baseWeight;

        if (rarity == 1) {
            baseWeight = COMMON_WEIGHT;
        } else if (rarity == 2) {
            baseWeight = UNCOMMON_WEIGHT;
        } else if (rarity == 3) {
            baseWeight = RARE_WEIGHT;
        } else if (rarity == 4) {
            baseWeight = LEGENDARY_WEIGHT;
        } else {
            revert InvalidProbabilityInput("Invalid rarity level");
        }

        // Apply odds improvement based on burned tokens
        uint256 improvement = (userBurnedAmount / (1000 * 10**18)) * baseOddsImprovement;

        // Cap improvement at 50% of base weight
        if (improvement > baseWeight / 2) {
            improvement = baseWeight / 2;
        }

        // For rare items, improvement increases probability
        // For common items, improvement slightly decreases probability
        if (rarity >= 3) {
            probability = baseWeight + improvement;
        } else {
            probability = baseWeight - (improvement / 4);
        }

        // Ensure probability doesn't go negative or exceed total weight
        if (probability > TOTAL_WEIGHT) {
            probability = TOTAL_WEIGHT;
        }
    }

    /**
     * @dev Select a random item from cabinet based on weighted probabilities
     */
    function selectRandomItem(
        GachaItem[] memory items,
        uint256 randomSeed,
        uint256 userBurnedAmount
    ) internal pure returns (uint256 selectedIndex) {
        if (items.length == 0) {
            revert NoEligibleItems(0);
        }

        if (randomSeed == 0) {
            revert InvalidRandomSeed(randomSeed);
        }

        // Calculate cumulative weights
        uint256[] memory cumulativeWeights = new uint256[](items.length);
        uint256 totalWeight = 0;

        for (uint256 i = 0; i < items.length; i++) {
            if (items[i].isActive) {
                uint256 itemProbability = calculateItemProbability(
                    items[i].rarity,
                    userBurnedAmount,
                    1 // base odds improvement factor
                );

                totalWeight += itemProbability;
                cumulativeWeights[i] = totalWeight;
            } else {
                cumulativeWeights[i] = totalWeight; // Skip inactive items
            }
        }

        if (totalWeight == 0) {
            revert NoEligibleItems(0);
        }

        // Generate random number within total weight
        uint256 randomValue = (randomSeed % totalWeight) + 1;

        // Find the selected item using binary search-like approach
        for (uint256 i = 0; i < items.length; i++) {
            if (randomValue <= cumulativeWeights[i] && items[i].isActive) {
                return i;
            }
        }

        // Fallback: return first active item
        for (uint256 i = 0; i < items.length; i++) {
            if (items[i].isActive) {
                return i;
            }
        }

        revert NoEligibleItems(0);
    }

    /**
     * @dev Generate multi-entropy random seed
     */
    function generateRandomSeed(
        uint256 nonce,
        address player,
        uint256 cabinetId,
        uint256 blockNumber
    ) internal view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    block.prevrandao,
                    block.timestamp,
                    block.number,
                    blockNumber,
                    player,
                    cabinetId,
                    nonce,
                    gasleft()
                )
            )
        );
    }

    /**
     * @dev Calculate play cost with dynamic pricing
     */
    function calculatePlayCost(
        uint256 basePrice,
        uint256 cabinetPopularity,
        uint256 timeOfDay,
        bool hasPremiumItems
    ) internal pure returns (uint256 adjustedPrice) {
        adjustedPrice = basePrice;

        // Popularity adjustment (0-100 scale)
        if (cabinetPopularity > 80) {
            adjustedPrice = (adjustedPrice * 110) / 100; // +10%
        } else if (cabinetPopularity > 60) {
            adjustedPrice = (adjustedPrice * 105) / 100; // +5%
        } else if (cabinetPopularity < 20) {
            adjustedPrice = (adjustedPrice * 95) / 100; // -5%
        }

        // Peak hours adjustment (simplified: hour 18-22)
        uint256 hour = (timeOfDay / 3600) % 24;
        if (hour >= 18 && hour <= 22) {
            adjustedPrice = (adjustedPrice * 102) / 100; // +2%
        }

        // Premium items adjustment
        if (hasPremiumItems) {
            adjustedPrice = (adjustedPrice * 103) / 100; // +3%
        }

        return adjustedPrice;
    }

    /**
     * @dev Calculate token emission for failed plays
     */
    function calculateTokenEmission(
        uint256 playPrice,
        uint256 cabinetPerformance,
        uint256 playerLoyalty,
        uint256 emissionRate
    ) internal pure returns (uint256 emissionAmount) {
        // Base emission is percentage of play price
        emissionAmount = (playPrice * emissionRate) / 10000;

        // Cabinet performance bonus (0-100 scale)
        if (cabinetPerformance > 80) {
            emissionAmount = (emissionAmount * 110) / 100; // +10%
        } else if (cabinetPerformance > 60) {
            emissionAmount = (emissionAmount * 105) / 100; // +5%
        }

        // Player loyalty bonus (number of plays)
        if (playerLoyalty > 100) {
            emissionAmount = (emissionAmount * 108) / 100; // +8%
        } else if (playerLoyalty > 50) {
            emissionAmount = (emissionAmount * 104) / 100; // +4%
        } else if (playerLoyalty > 10) {
            emissionAmount = (emissionAmount * 102) / 100; // +2%
        }

        return emissionAmount;
    }

    /**
     * @dev Calculate odds improvement percentage from burned tokens
     */
    function calculateOddsImprovement(
        uint256 burnedAmount,
        uint256 burnCount,
        uint256 maxImprovement
    ) internal pure returns (uint256 improvement) {
        // Base improvement: 1 basis point per 1000 tokens burned
        improvement = (burnedAmount / (1000 * 10**18)) * 1;

        // Burn frequency bonus (up to 25% bonus for frequent burners)
        if (burnCount > 50) {
            improvement = (improvement * 125) / 100;
        } else if (burnCount > 20) {
            improvement = (improvement * 115) / 100;
        } else if (burnCount > 10) {
            improvement = (improvement * 110) / 100;
        } else if (burnCount > 5) {
            improvement = (improvement * 105) / 100;
        }

        // Cap at maximum improvement
        if (improvement > maxImprovement) {
            improvement = maxImprovement;
        }

        return improvement;
    }

    /**
     * @dev Validate game parameters before execution
     */
    function validateGameParameters(
        uint256 cabinetId,
        uint256 paymentAmount,
        uint256 requiredPrice,
        address player
    ) internal pure {
        if (cabinetId == 0) {
            revert InvalidProbabilityInput("Invalid cabinet ID");
        }

        if (paymentAmount < requiredPrice) {
            revert InvalidProbabilityInput("Insufficient payment");
        }

        if (player == address(0)) {
            revert InvalidProbabilityInput("Invalid player address");
        }
    }

    /**
     * @dev Calculate rarity distribution for cabinet analytics
     */
    function calculateRarityDistribution(
        GachaItem[] memory items
    ) internal pure returns (uint256[4] memory distribution) {
        for (uint256 i = 0; i < items.length; i++) {
            if (items[i].isActive && items[i].rarity >= 1 && items[i].rarity <= 4) {
                distribution[items[i].rarity - 1]++;
            }
        }

        return distribution;
    }

    /**
     * @dev Check if cabinet has balanced rarity distribution
     */
    function isBalancedDistribution(
        GachaItem[] memory items,
        uint256 minItemsPerRarity
    ) internal pure returns (bool balanced) {
        uint256[4] memory distribution = calculateRarityDistribution(items);

        // Check if each rarity tier has minimum items (if any items exist for that tier)
        for (uint256 i = 0; i < 4; i++) {
            if (distribution[i] > 0 && distribution[i] < minItemsPerRarity) {
                return false;
            }
        }

        // Check if there's at least one item of common or uncommon rarity
        if (distribution[0] == 0 && distribution[1] == 0) {
            return false;
        }

        return true;
    }

    /**
     * @dev Estimate cabinet value based on items
     */
    function estimateCabinetValue(
        GachaItem[] memory items,
        uint256[4] memory rarityValues
    ) internal pure returns (uint256 estimatedValue) {
        for (uint256 i = 0; i < items.length; i++) {
            if (items[i].isActive && items[i].rarity >= 1 && items[i].rarity <= 4) {
                estimatedValue += rarityValues[items[i].rarity - 1];
            }
        }

        return estimatedValue;
    }
}