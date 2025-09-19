// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./Utils/Security/TuuKeepAccessControl.sol";
import "./Utils/Security/ValidationLib.sol";
import "./Utils/TuuKeepErrors.sol";

/**
 * @title TuuKeepMarketplaceFees
 * @dev Fee management contract for TuuKeep Marketplace
 * Handles platform fee calculations, collection, and distribution
 */
contract TuuKeepMarketplaceFees is AccessControl, Pausable {
    // Access control roles
    bytes32 public constant MARKETPLACE_ADMIN_ROLE = keccak256("MARKETPLACE_ADMIN_ROLE");
    bytes32 public constant EMERGENCY_RESPONDER_ROLE = keccak256("EMERGENCY_RESPONDER_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    // Platform integration
    TuuKeepAccessControl public immutable accessControl;
    address public marketplaceCoreContract;

    // Fee configuration
    struct FeeConfig {
        uint256 platformFeeRate;    // Platform fee in basis points (500 = 5%)
        address feeRecipient;       // Platform fee recipient
        uint256 minFeeAmount;       // Minimum fee amount in wei
        bool dynamicFeesEnabled;    // Enable dynamic fee adjustments
    }

    FeeConfig public feeConfig;

    // Fee tracking
    mapping(address => uint256) public userFeesCollected;
    mapping(uint256 => uint256) public dailyFeesCollected;
    uint256 public totalFeesCollected;
    uint256 public totalFeeTransactions;

    // Dynamic fee tiers (for high-volume sellers)
    struct FeeTier {
        uint256 volumeThreshold;    // Minimum volume for this tier
        uint256 feeRate;           // Fee rate in basis points
        bool isActive;             // Whether this tier is active
    }

    mapping(uint256 => FeeTier) public feeTiers;
    mapping(address => uint256) public userVolume;
    uint256 public totalFeeTiers;

    // Constants
    uint256 public constant DEFAULT_PLATFORM_FEE_RATE = 500; // 5%
    uint256 public constant MAX_PLATFORM_FEE_RATE = 1000;    // 10%
    uint256 public constant MIN_FEE_AMOUNT = 0.0001 ether;   // Minimum fee

    // Events
    event FeeConfigUpdated(
        uint256 platformFeeRate,
        address feeRecipient,
        uint256 minFeeAmount,
        bool dynamicFeesEnabled
    );

    event FeeCollected(
        address indexed user,
        uint256 saleAmount,
        uint256 feeAmount,
        uint256 sellerAmount
    );

    event FeeDistributed(
        address indexed recipient,
        uint256 amount
    );

    event FeeTierAdded(
        uint256 indexed tierId,
        uint256 volumeThreshold,
        uint256 feeRate
    );

    event FeeTierUpdated(
        uint256 indexed tierId,
        uint256 volumeThreshold,
        uint256 feeRate,
        bool isActive
    );

    event UserVolumeUpdated(
        address indexed user,
        uint256 newVolume,
        uint256 newTier
    );

    // Custom errors
    error InvalidFeeRate(uint256 rate);
    error InvalidFeeRecipient(address recipient);
    error FeeDistributionFailed(address recipient, uint256 amount);
    error OnlyMarketplaceCore();
    error InvalidFeeTier(uint256 tierId);

    modifier onlyMarketplaceCore() {
        if (msg.sender != marketplaceCoreContract) {
            revert OnlyMarketplaceCore();
        }
        _;
    }

    constructor(
        address _accessControl,
        address _feeRecipient
    ) {
        require(_accessControl != address(0), "TuuKeepMarketplaceFees: invalid access control address");
        require(_feeRecipient != address(0), "TuuKeepMarketplaceFees: invalid fee recipient");

        accessControl = TuuKeepAccessControl(_accessControl);

        // Initialize fee configuration
        feeConfig = FeeConfig({
            platformFeeRate: DEFAULT_PLATFORM_FEE_RATE,
            feeRecipient: _feeRecipient,
            minFeeAmount: MIN_FEE_AMOUNT,
            dynamicFeesEnabled: false
        });

        // Grant admin roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MARKETPLACE_ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_RESPONDER_ROLE, msg.sender);
        _grantRole(FEE_MANAGER_ROLE, msg.sender);

        // Initialize default fee tiers
        _initializeDefaultFeeTiers();
    }

    /**
     * @dev Set the marketplace core contract address
     */
    function setMarketplaceCoreContract(address _marketplaceCoreContract)
        external
        onlyRole(MARKETPLACE_ADMIN_ROLE)
    {
        ValidationLib.validateContract(_marketplaceCoreContract, "marketplace core contract");
        marketplaceCoreContract = _marketplaceCoreContract;
    }

    /**
     * @dev Calculate fees for a sale (called by marketplace core)
     */
    function calculateFees(uint256 salePrice)
        external
        view
        returns (uint256 platformFee, uint256 sellerAmount)
    {
        uint256 feeRate = _getUserFeeRate(tx.origin); // Use tx.origin to get the actual user

        platformFee = (salePrice * feeRate) / 10000;

        // Apply minimum fee if configured
        if (platformFee < feeConfig.minFeeAmount) {
            platformFee = feeConfig.minFeeAmount;
        }

        // Ensure fee doesn't exceed sale price
        if (platformFee > salePrice) {
            platformFee = salePrice;
        }

        sellerAmount = salePrice - platformFee;
    }

    /**
     * @dev Distribute collected fees (called by marketplace core)
     */
    function distributeFee() external payable onlyMarketplaceCore {
        uint256 feeAmount = msg.value;

        if (feeAmount > 0) {
            // Update tracking
            totalFeesCollected += feeAmount;
            totalFeeTransactions += 1;

            uint256 today = block.timestamp / 1 days;
            dailyFeesCollected[today] += feeAmount;

            // Transfer to fee recipient
            (bool success, ) = payable(feeConfig.feeRecipient).call{value: feeAmount}("");
            if (!success) {
                revert FeeDistributionFailed(feeConfig.feeRecipient, feeAmount);
            }

            emit FeeDistributed(feeConfig.feeRecipient, feeAmount);
        }
    }

    /**
     * @dev Update user volume after a sale (called by marketplace core)
     */
    function updateUserVolume(address user, uint256 saleAmount)
        external
        onlyMarketplaceCore
    {
        userVolume[user] += saleAmount;
        userFeesCollected[user] += (saleAmount * _getUserFeeRate(user)) / 10000;

        uint256 newTier = _getUserFeeTier(user);
        emit UserVolumeUpdated(user, userVolume[user], newTier);
    }

    // ============ FEE CONFIGURATION FUNCTIONS ============

    /**
     * @dev Update fee configuration
     */
    function updateFeeConfig(FeeConfig memory newConfig)
        external
        onlyRole(FEE_MANAGER_ROLE)
    {
        // Validate configuration
        if (newConfig.platformFeeRate > MAX_PLATFORM_FEE_RATE) {
            revert InvalidFeeRate(newConfig.platformFeeRate);
        }

        if (newConfig.feeRecipient == address(0)) {
            revert InvalidFeeRecipient(newConfig.feeRecipient);
        }

        feeConfig = newConfig;

        emit FeeConfigUpdated(
            newConfig.platformFeeRate,
            newConfig.feeRecipient,
            newConfig.minFeeAmount,
            newConfig.dynamicFeesEnabled
        );
    }

    /**
     * @dev Add a new fee tier
     */
    function addFeeTier(
        uint256 volumeThreshold,
        uint256 feeRate
    ) external onlyRole(FEE_MANAGER_ROLE) {
        if (feeRate > MAX_PLATFORM_FEE_RATE) {
            revert InvalidFeeRate(feeRate);
        }

        uint256 tierId = totalFeeTiers++;

        feeTiers[tierId] = FeeTier({
            volumeThreshold: volumeThreshold,
            feeRate: feeRate,
            isActive: true
        });

        emit FeeTierAdded(tierId, volumeThreshold, feeRate);
    }

    /**
     * @dev Update an existing fee tier
     */
    function updateFeeTier(
        uint256 tierId,
        uint256 volumeThreshold,
        uint256 feeRate,
        bool isActive
    ) external onlyRole(FEE_MANAGER_ROLE) {
        if (tierId >= totalFeeTiers) {
            revert InvalidFeeTier(tierId);
        }

        if (feeRate > MAX_PLATFORM_FEE_RATE) {
            revert InvalidFeeRate(feeRate);
        }

        feeTiers[tierId] = FeeTier({
            volumeThreshold: volumeThreshold,
            feeRate: feeRate,
            isActive: isActive
        });

        emit FeeTierUpdated(tierId, volumeThreshold, feeRate, isActive);
    }

    // ============ INTERNAL FUNCTIONS ============

    /**
     * @dev Initialize default fee tiers
     */
    function _initializeDefaultFeeTiers() internal {
        // Tier 0: Default rate for all users
        feeTiers[0] = FeeTier({
            volumeThreshold: 0,
            feeRate: DEFAULT_PLATFORM_FEE_RATE,
            isActive: true
        });

        // Tier 1: Reduced rate for high volume sellers (>10 KUB volume)
        feeTiers[1] = FeeTier({
            volumeThreshold: 10 ether,
            feeRate: 400, // 4%
            isActive: true
        });

        // Tier 2: Further reduced rate for very high volume sellers (>50 KUB volume)
        feeTiers[2] = FeeTier({
            volumeThreshold: 50 ether,
            feeRate: 300, // 3%
            isActive: true
        });

        totalFeeTiers = 3;
    }

    /**
     * @dev Get applicable fee rate for a user
     */
    function _getUserFeeRate(address user) internal view returns (uint256) {
        if (!feeConfig.dynamicFeesEnabled) {
            return feeConfig.platformFeeRate;
        }

        uint256 volume = userVolume[user];
        uint256 applicableFeeRate = feeConfig.platformFeeRate;

        // Find the highest tier the user qualifies for
        for (uint256 i = 0; i < totalFeeTiers; i++) {
            FeeTier memory tier = feeTiers[i];
            if (tier.isActive && volume >= tier.volumeThreshold) {
                applicableFeeRate = tier.feeRate;
            }
        }

        return applicableFeeRate;
    }

    /**
     * @dev Get the fee tier a user belongs to
     */
    function _getUserFeeTier(address user) internal view returns (uint256) {
        if (!feeConfig.dynamicFeesEnabled) {
            return 0;
        }

        uint256 volume = userVolume[user];
        uint256 applicableTier = 0;

        // Find the highest tier the user qualifies for
        for (uint256 i = 0; i < totalFeeTiers; i++) {
            FeeTier memory tier = feeTiers[i];
            if (tier.isActive && volume >= tier.volumeThreshold) {
                applicableTier = i;
            }
        }

        return applicableTier;
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Get fee configuration
     */
    function getFeeConfig() external view returns (FeeConfig memory) {
        return feeConfig;
    }

    /**
     * @dev Get user's fee rate
     */
    function getUserFeeRate(address user) external view returns (uint256) {
        return _getUserFeeRate(user);
    }

    /**
     * @dev Get user's fee tier
     */
    function getUserFeeTier(address user) external view returns (uint256) {
        return _getUserFeeTier(user);
    }

    /**
     * @dev Get fee tier information
     */
    function getFeeTier(uint256 tierId) external view returns (FeeTier memory) {
        return feeTiers[tierId];
    }

    /**
     * @dev Get user volume and fees collected
     */
    function getUserStats(address user) external view returns (uint256 volume, uint256 fees, uint256 tier) {
        return (userVolume[user], userFeesCollected[user], _getUserFeeTier(user));
    }

    /**
     * @dev Get daily fee collection data
     */
    function getDailyFees(uint256 day) external view returns (uint256) {
        return dailyFeesCollected[day];
    }

    /**
     * @dev Get total fee statistics
     */
    function getTotalFeeStats() external view returns (uint256 total, uint256 transactions) {
        return (totalFeesCollected, totalFeeTransactions);
    }

    // ============ ADMINISTRATIVE FUNCTIONS ============

    /**
     * @dev Emergency withdraw function
     */
    function emergencyWithdraw() external onlyRole(EMERGENCY_RESPONDER_ROLE) {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(feeConfig.feeRecipient).call{value: balance}("");
            if (!success) {
                revert FeeDistributionFailed(feeConfig.feeRecipient, balance);
            }
        }
    }

    /**
     * @dev Pause the fee contract
     */
    function pause() external onlyRole(EMERGENCY_RESPONDER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the fee contract
     */
    function unpause() external onlyRole(EMERGENCY_RESPONDER_ROLE) {
        _unpause();
    }

    /**
     * @dev Check if fee contract supports a specific interface
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Receive function to accept ETH payments
     */
    receive() external payable {
        // Allow the contract to receive ETH
    }
}