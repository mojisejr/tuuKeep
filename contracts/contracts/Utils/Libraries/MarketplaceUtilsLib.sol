// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title MarketplaceUtilsLib
 * @dev Library for marketplace utility functions and calculations
 */
library MarketplaceUtilsLib {

    // Fee calculation constants
    uint256 public constant BASIS_POINTS_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE_RATE = 1000; // 10%
    uint256 public constant MIN_FEE_AMOUNT = 0.0001 ether;

    // Time constants
    uint256 public constant SECONDS_PER_DAY = 86400;
    uint256 public constant SECONDS_PER_HOUR = 3600;

    // Custom errors
    error InvalidFeeCalculation(string reason);
    error InvalidTimeRange(uint256 start, uint256 end);
    error InvalidPriceRange(uint256 min, uint256 max);

    /**
     * @dev Calculate platform fee and seller amount
     */
    function calculateFees(
        uint256 salePrice,
        uint256 feeRate,
        uint256 minFeeAmount
    ) internal pure returns (uint256 platformFee, uint256 sellerAmount) {
        if (feeRate > MAX_FEE_RATE) {
            revert InvalidFeeCalculation("Fee rate exceeds maximum");
        }

        platformFee = (salePrice * feeRate) / BASIS_POINTS_DENOMINATOR;

        // Apply minimum fee if configured
        if (platformFee < minFeeAmount && minFeeAmount <= salePrice) {
            platformFee = minFeeAmount;
        }

        // Ensure fee doesn't exceed sale price
        if (platformFee > salePrice) {
            platformFee = salePrice;
        }

        sellerAmount = salePrice - platformFee;
    }

    /**
     * @dev Calculate volume-based fee discount
     */
    function calculateVolumeDiscount(
        uint256 userVolume,
        uint256 baseFeeRate
    ) internal pure returns (uint256 discountedFeeRate) {
        // Volume tiers for fee discounts
        if (userVolume >= 100 ether) {
            // 20% discount for 100+ ETH volume
            discountedFeeRate = (baseFeeRate * 80) / 100;
        } else if (userVolume >= 50 ether) {
            // 15% discount for 50+ ETH volume
            discountedFeeRate = (baseFeeRate * 85) / 100;
        } else if (userVolume >= 20 ether) {
            // 10% discount for 20+ ETH volume
            discountedFeeRate = (baseFeeRate * 90) / 100;
        } else if (userVolume >= 10 ether) {
            // 5% discount for 10+ ETH volume
            discountedFeeRate = (baseFeeRate * 95) / 100;
        } else {
            discountedFeeRate = baseFeeRate;
        }

        return discountedFeeRate;
    }

    /**
     * @dev Calculate price trend over time period
     */
    function calculatePriceTrend(
        uint256[] memory prices,
        uint256[] memory timestamps,
        uint256 timeWindow
    ) internal view returns (int256 trend, uint256 avgPrice) {
        if (prices.length != timestamps.length || prices.length < 2) {
            return (0, 0);
        }

        uint256 currentTime = block.timestamp;
        uint256 startTime = currentTime - timeWindow;

        uint256 validPrices = 0;
        uint256 totalPrice = 0;
        uint256 firstValidPrice = 0;
        uint256 lastValidPrice = 0;
        bool foundFirst = false;

        for (uint256 i = 0; i < prices.length; i++) {
            if (timestamps[i] >= startTime) {
                totalPrice += prices[i];
                validPrices++;

                if (!foundFirst) {
                    firstValidPrice = prices[i];
                    foundFirst = true;
                }
                lastValidPrice = prices[i];
            }
        }

        if (validPrices == 0) {
            return (0, 0);
        }

        avgPrice = totalPrice / validPrices;

        if (validPrices >= 2) {
            // Calculate trend as percentage change
            if (firstValidPrice > 0) {
                trend = int256((lastValidPrice * 100) / firstValidPrice) - 100;
            }
        }

        return (trend, avgPrice);
    }

    /**
     * @dev Calculate market volatility
     */
    function calculateVolatility(
        uint256[] memory prices,
        uint256 avgPrice
    ) internal pure returns (uint256 volatility) {
        if (prices.length < 2 || avgPrice == 0) {
            return 0;
        }

        uint256 sumSquaredDeviations = 0;

        for (uint256 i = 0; i < prices.length; i++) {
            uint256 deviation = prices[i] > avgPrice ?
                prices[i] - avgPrice :
                avgPrice - prices[i];
            sumSquaredDeviations += (deviation * deviation);
        }

        // Return standard deviation as percentage of average price
        uint256 variance = sumSquaredDeviations / prices.length;
        uint256 stdDev = _sqrt(variance);

        volatility = (stdDev * 100) / avgPrice;
        return volatility;
    }

    /**
     * @dev Calculate listing performance score
     */
    function calculateListingScore(
        uint256 listingAge,
        uint256 priceCompetitiveness,
        uint256 sellerReputation,
        uint256 itemRarity
    ) internal pure returns (uint256 score) {
        // Base score starts at 50
        score = 50;

        // Age factor (newer listings get slight boost)
        if (listingAge < 1 days) {
            score += 10;
        } else if (listingAge < 3 days) {
            score += 5;
        } else if (listingAge > 7 days) {
            score -= 5;
        }

        // Price competitiveness (0-100 scale)
        score += (priceCompetitiveness * 30) / 100;

        // Seller reputation (0-100 scale)
        score += (sellerReputation * 15) / 100;

        // Item rarity bonus
        if (itemRarity == 4) { // Legendary
            score += 15;
        } else if (itemRarity == 3) { // Rare
            score += 10;
        } else if (itemRarity == 2) { // Uncommon
            score += 5;
        }

        // Cap score at 100
        if (score > 100) {
            score = 100;
        }

        return score;
    }

    /**
     * @dev Calculate optimal listing duration based on market conditions
     */
    function calculateOptimalDuration(
        uint256 basePrice,
        uint256 marketAvgPrice,
        uint256 marketVolatility,
        uint256 minDuration,
        uint256 maxDuration
    ) internal pure returns (uint256 optimalDuration) {
        // Start with middle duration
        optimalDuration = (minDuration + maxDuration) / 2;

        // Price competitiveness adjustment
        if (basePrice <= marketAvgPrice) {
            // Competitive price - shorter duration for quick sale
            optimalDuration = (optimalDuration * 80) / 100;
        } else if (basePrice > (marketAvgPrice * 120) / 100) {
            // High price - longer duration to find right buyer
            optimalDuration = (optimalDuration * 120) / 100;
        }

        // Market volatility adjustment
        if (marketVolatility > 50) {
            // High volatility - shorter duration to avoid price swings
            optimalDuration = (optimalDuration * 70) / 100;
        } else if (marketVolatility < 20) {
            // Stable market - can afford longer duration
            optimalDuration = (optimalDuration * 110) / 100;
        }

        // Ensure within bounds
        if (optimalDuration < minDuration) {
            optimalDuration = minDuration;
        } else if (optimalDuration > maxDuration) {
            optimalDuration = maxDuration;
        }

        return optimalDuration;
    }

    /**
     * @dev Validate listing parameters
     */
    function validateListingParams(
        uint256 price,
        uint256 duration,
        uint256 minPrice,
        uint256 minDuration,
        uint256 maxDuration
    ) internal pure {
        if (price < minPrice) {
            revert InvalidPriceRange(price, minPrice);
        }

        if (duration < minDuration || duration > maxDuration) {
            revert InvalidTimeRange(duration, minDuration);
        }
    }

    /**
     * @dev Calculate market summary statistics
     */
    function calculateMarketSummary(
        uint256[] memory recentPrices,
        uint256[] memory recentVolumes,
        uint256 timeWindow
    ) internal view returns (
        uint256 avgPrice,
        uint256 totalVolume,
        uint256 priceChange,
        uint256 volumeChange
    ) {
        if (recentPrices.length == 0) {
            return (0, 0, 0, 0);
        }

        // Calculate average price
        uint256 priceSum = 0;
        for (uint256 i = 0; i < recentPrices.length; i++) {
            priceSum += recentPrices[i];
        }
        avgPrice = priceSum / recentPrices.length;

        // Calculate total volume
        for (uint256 i = 0; i < recentVolumes.length; i++) {
            totalVolume += recentVolumes[i];
        }

        // Calculate price change (simplified)
        if (recentPrices.length >= 2) {
            uint256 firstPrice = recentPrices[0];
            uint256 lastPrice = recentPrices[recentPrices.length - 1];

            if (firstPrice > 0) {
                priceChange = ((lastPrice * 100) / firstPrice);
                priceChange = priceChange > 100 ? priceChange - 100 : 100 - priceChange;
            }
        }

        // Calculate volume change (simplified)
        if (recentVolumes.length >= 2) {
            uint256 firstHalfVolume = 0;
            uint256 secondHalfVolume = 0;
            uint256 mid = recentVolumes.length / 2;

            for (uint256 i = 0; i < mid; i++) {
                firstHalfVolume += recentVolumes[i];
            }
            for (uint256 i = mid; i < recentVolumes.length; i++) {
                secondHalfVolume += recentVolumes[i];
            }

            if (firstHalfVolume > 0) {
                volumeChange = ((secondHalfVolume * 100) / firstHalfVolume);
                volumeChange = volumeChange > 100 ? volumeChange - 100 : 100 - volumeChange;
            }
        }
    }

    /**
     * @dev Get current day timestamp for analytics
     */
    function getCurrentDay() internal view returns (uint256) {
        return block.timestamp / SECONDS_PER_DAY;
    }

    /**
     * @dev Get current hour timestamp for analytics
     */
    function getCurrentHour() internal view returns (uint256) {
        return block.timestamp / SECONDS_PER_HOUR;
    }

    /**
     * @dev Check if listing has expired
     */
    function isListingExpired(uint256 expiresAt) internal view returns (bool) {
        return block.timestamp > expiresAt;
    }

    /**
     * @dev Calculate time remaining for listing
     */
    function getTimeRemaining(uint256 expiresAt) internal view returns (uint256) {
        if (block.timestamp >= expiresAt) {
            return 0;
        }
        return expiresAt - block.timestamp;
    }

    /**
     * @dev Simple square root implementation for volatility calculation
     */
    function _sqrt(uint256 x) private pure returns (uint256) {
        if (x == 0) return 0;

        uint256 z = (x + 1) / 2;
        uint256 y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }

        return y;
    }
}