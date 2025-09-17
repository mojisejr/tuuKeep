// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./TuuKeepCabinet.sol";
import "./Utils/Security/ValidationLib.sol";

/**
 * @title TuuKeepTierSale
 * @dev Tier-based cabinet NFT sale system for TuuKeep platform
 *
 * Features:
 * - Phase-based sales with configurable tier pricing
 * - Automatic tier progression based on quantity or time
 * - ETH/KUB payment processing with revenue distribution
 * - Integration with TuuKeepCabinet for instant NFT minting
 * - Gas optimized (target <200k per purchase)
 * - Comprehensive security with reentrancy protection
 *
 * Phase 1 Configuration:
 * - Super Early Bird: 5 cabinets × 6 KUB (70% discount)
 * - Early Bird: 20 cabinets × 16 KUB (20% discount)
 * - Regular: 25 cabinets × 20 KUB (normal price)
 * - Total: 50 cabinets, 850 KUB revenue target
 */
contract TuuKeepTierSale is AccessControl, ReentrancyGuard, Pausable {
    using ValidationLib for *;

    /// @dev Custom errors for gas efficiency
    error InvalidPhase(uint256 phaseId);
    error InvalidTier(uint256 tierId);
    error PhaseNotActive(uint256 phaseId);
    error TierSoldOut(uint256 phaseId, uint256 tierId);
    error InsufficientPayment(uint256 required, uint256 provided);
    error TransferFailed(address to, uint256 amount);
    error PhaseLimitExceeded(uint256 phaseId, uint256 limit);
    error InvalidPricing(uint256 basePrice, uint256 tierPrice);
    error InvalidConfiguration(string parameter, string reason);

    /// @dev Role definitions
    bytes32 public constant SALE_MANAGER_ROLE = keccak256("SALE_MANAGER_ROLE");
    bytes32 public constant PLATFORM_ADMIN_ROLE = keccak256("PLATFORM_ADMIN_ROLE");

    /// @dev Core contract references
    TuuKeepCabinet public immutable cabinetContract;
    address public immutable platformTreasury;

    /// @dev Pricing tier structure
    struct PricingTier {
        string name;                // Tier name (e.g., "Super Early Bird")
        uint256 price;             // Price per cabinet in wei
        uint256 maxQuantity;       // Maximum cabinets for this tier
        uint256 soldQuantity;      // Number of cabinets sold in this tier
        uint256 startTime;         // Tier availability start time (0 = immediate)
        uint256 endTime;           // Tier availability end time (0 = no limit)
        bool isActive;             // Whether this tier is currently active
        uint16 discountBps;        // Discount in basis points (7000 = 70%)
    }

    /// @dev Sale phase structure
    struct SalePhase {
        string name;               // Phase name (e.g., "Genesis Sale")
        uint256 startTime;         // Phase start timestamp
        uint256 endTime;           // Phase end timestamp (0 = no limit)
        uint256 totalCabinets;     // Total cabinets available in this phase
        uint256 soldCabinets;      // Total cabinets sold in this phase
        uint256 basePrice;         // Base price before tier discounts
        bool isActive;             // Whether this phase is currently active
        uint256[] tierIds;         // Array of tier IDs for this phase
    }

    /// @dev Purchase record for analytics
    struct Purchase {
        address buyer;
        uint256 phaseId;
        uint256 tierId;
        uint256 cabinetId;
        uint256 price;
        uint256 timestamp;
    }

    /// @dev State variables
    mapping(uint256 => SalePhase) public salePhases;
    mapping(uint256 => PricingTier) public pricingTiers;
    mapping(uint256 => Purchase) public purchases;

    uint256 public currentPhaseId;
    uint256 public nextTierId;
    uint256 public nextPurchaseId;
    uint256 public totalRevenue;
    uint256 public platformFeeRate = 500; // 5% platform fee in basis points

    /// @dev Events
    event PhaseCreated(
        uint256 indexed phaseId,
        string name,
        uint256 startTime,
        uint256 endTime,
        uint256 totalCabinets,
        uint256 basePrice
    );

    event TierCreated(
        uint256 indexed tierId,
        uint256 indexed phaseId,
        string name,
        uint256 price,
        uint256 maxQuantity,
        uint16 discountBps
    );

    event CabinetPurchased(
        uint256 indexed purchaseId,
        address indexed buyer,
        uint256 indexed cabinetId,
        uint256 phaseId,
        uint256 tierId,
        uint256 price
    );

    event PhaseActivated(uint256 indexed phaseId);
    event PhaseDeactivated(uint256 indexed phaseId);
    event TierActivated(uint256 indexed tierId);
    event TierDeactivated(uint256 indexed tierId);
    event RevenueWithdrawn(address indexed to, uint256 amount);

    /**
     * @dev Constructor
     * @param _cabinetContract Address of TuuKeepCabinet contract
     * @param _platformTreasury Address to receive platform fees
     * @param _admin Address with admin privileges
     */
    constructor(
        address _cabinetContract,
        address _platformTreasury,
        address _admin
    ) {
        _cabinetContract.validateContract("cabinet contract");
        _platformTreasury.validateAddress("platform treasury");
        _admin.validateAddress("admin");

        cabinetContract = TuuKeepCabinet(_cabinetContract);
        platformTreasury = _platformTreasury;

        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(SALE_MANAGER_ROLE, _admin);
        _grantRole(PLATFORM_ADMIN_ROLE, _admin);
    }

    /**
     * @dev Create a new sale phase
     * @param name Phase name
     * @param startTime Phase start timestamp
     * @param endTime Phase end timestamp (0 for no limit)
     * @param totalCabinets Total cabinets available
     * @param basePrice Base price before tier discounts
     * @return phaseId The ID of the created phase
     */
    function createSalePhase(
        string memory name,
        uint256 startTime,
        uint256 endTime,
        uint256 totalCabinets,
        uint256 basePrice
    ) external onlyRole(SALE_MANAGER_ROLE) returns (uint256 phaseId) {
        name.validateNonEmptyString("phase name");
        totalCabinets.validateAmount(1, 1000, "total cabinets");
        basePrice.validateAmount(1e15, 1e21, "base price"); // 0.001 to 1000 ETH

        if (endTime > 0) {
            endTime.validateFutureTimestamp("phase end time");
            if (startTime >= endTime) {
                revert InvalidConfiguration("start time", "must be before end time");
            }
        }

        phaseId = currentPhaseId++;

        SalePhase storage phase = salePhases[phaseId];
        phase.name = name;
        phase.startTime = startTime;
        phase.endTime = endTime;
        phase.totalCabinets = totalCabinets;
        phase.basePrice = basePrice;
        phase.isActive = true;

        emit PhaseCreated(phaseId, name, startTime, endTime, totalCabinets, basePrice);
    }

    /**
     * @dev Add a pricing tier to a phase
     * @param phaseId Target phase ID
     * @param name Tier name
     * @param maxQuantity Maximum cabinets for this tier
     * @param discountBps Discount in basis points (7000 = 70%)
     * @param startTime Tier start time (0 for immediate)
     * @param endTime Tier end time (0 for no limit)
     * @return tierId The ID of the created tier
     */
    function addTierToPhase(
        uint256 phaseId,
        string memory name,
        uint256 maxQuantity,
        uint16 discountBps,
        uint256 startTime,
        uint256 endTime
    ) external onlyRole(SALE_MANAGER_ROLE) returns (uint256 tierId) {
        if (phaseId >= currentPhaseId) revert InvalidPhase(phaseId);

        SalePhase storage phase = salePhases[phaseId];
        name.validateNonEmptyString("tier name");
        maxQuantity.validateAmount(1, phase.totalCabinets, "tier quantity");
        discountBps.validateBasisPoints("discount");

        // Calculate tier price with discount
        uint256 tierPrice = phase.basePrice - (phase.basePrice * discountBps / 10000);
        if (tierPrice >= phase.basePrice) {
            revert InvalidPricing(phase.basePrice, tierPrice);
        }

        tierId = nextTierId++;

        PricingTier storage tier = pricingTiers[tierId];
        tier.name = name;
        tier.price = tierPrice;
        tier.maxQuantity = maxQuantity;
        tier.startTime = startTime;
        tier.endTime = endTime;
        tier.isActive = true;
        tier.discountBps = discountBps;

        // Add tier to phase
        phase.tierIds.push(tierId);

        emit TierCreated(tierId, phaseId, name, tierPrice, maxQuantity, discountBps);
    }

    /**
     * @dev Purchase a cabinet from the current active tier
     * @param phaseId Target phase ID
     * @param cabinetName Name for the purchased cabinet
     * @return cabinetId The ID of the minted cabinet
     */
    function purchaseCabinet(
        uint256 phaseId,
        string memory cabinetName
    ) external payable nonReentrant whenNotPaused returns (uint256 cabinetId) {
        if (phaseId >= currentPhaseId) revert InvalidPhase(phaseId);

        SalePhase storage phase = salePhases[phaseId];
        if (!phase.isActive) revert PhaseNotActive(phaseId);

        // Check phase timing
        if (block.timestamp < phase.startTime) revert PhaseNotActive(phaseId);
        if (phase.endTime > 0 && block.timestamp > phase.endTime) revert PhaseNotActive(phaseId);

        // Check phase availability
        if (phase.soldCabinets >= phase.totalCabinets) {
            revert PhaseLimitExceeded(phaseId, phase.totalCabinets);
        }

        // Get current active tier
        uint256 tierId = getCurrentTier(phaseId);
        PricingTier storage tier = pricingTiers[tierId];

        // Validate tier availability
        if (tier.soldQuantity >= tier.maxQuantity) {
            revert TierSoldOut(phaseId, tierId);
        }

        // Validate payment
        if (msg.value < tier.price) {
            revert InsufficientPayment(tier.price, msg.value);
        }

        // Update state
        tier.soldQuantity++;
        phase.soldCabinets++;

        // Calculate fees
        uint256 platformFee = (tier.price * platformFeeRate) / 10000;
        uint256 netRevenue = tier.price - platformFee;
        totalRevenue += netRevenue;

        // Mint cabinet NFT
        cabinetId = cabinetContract.mintCabinet(msg.sender, cabinetName);

        // Record purchase
        uint256 purchaseId = nextPurchaseId++;
        Purchase storage purchase = purchases[purchaseId];
        purchase.buyer = msg.sender;
        purchase.phaseId = phaseId;
        purchase.tierId = tierId;
        purchase.cabinetId = cabinetId;
        purchase.price = tier.price;
        purchase.timestamp = block.timestamp;

        // Transfer platform fee
        if (platformFee > 0) {
            (bool success, ) = platformTreasury.call{value: platformFee}("");
            if (!success) revert TransferFailed(platformTreasury, platformFee);
        }

        // Refund excess payment
        uint256 excess = msg.value - tier.price;
        if (excess > 0) {
            (bool success, ) = msg.sender.call{value: excess}("");
            if (!success) revert TransferFailed(msg.sender, excess);
        }

        emit CabinetPurchased(purchaseId, msg.sender, cabinetId, phaseId, tierId, tier.price);
    }

    /**
     * @dev Get the current active tier for a phase
     * @param phaseId Target phase ID
     * @return tierId Current active tier ID
     */
    function getCurrentTier(uint256 phaseId) public view returns (uint256 tierId) {
        if (phaseId >= currentPhaseId) revert InvalidPhase(phaseId);

        SalePhase storage phase = salePhases[phaseId];

        for (uint256 i = 0; i < phase.tierIds.length; i++) {
            uint256 checkTierId = phase.tierIds[i];
            PricingTier storage tier = pricingTiers[checkTierId];

            // Check if tier is active and available
            if (tier.isActive && tier.soldQuantity < tier.maxQuantity) {
                // Check timing constraints
                if (tier.startTime > 0 && block.timestamp < tier.startTime) continue;
                if (tier.endTime > 0 && block.timestamp > tier.endTime) continue;

                return checkTierId;
            }
        }

        revert InvalidTier(0); // No active tier found
    }

    /**
     * @dev Get current tier information
     * @param phaseId Target phase ID
     * @return tier Current tier information
     */
    function getCurrentTierInfo(uint256 phaseId) external view returns (PricingTier memory tier) {
        uint256 tierId = getCurrentTier(phaseId);
        return pricingTiers[tierId];
    }

    /**
     * @dev Get phase information with tier details
     * @param phaseId Target phase ID
     * @return phase Phase information
     * @return tiers Array of tier information
     */
    function getPhaseInfo(uint256 phaseId) external view returns (
        SalePhase memory phase,
        PricingTier[] memory tiers
    ) {
        if (phaseId >= currentPhaseId) revert InvalidPhase(phaseId);

        phase = salePhases[phaseId];
        tiers = new PricingTier[](phase.tierIds.length);

        for (uint256 i = 0; i < phase.tierIds.length; i++) {
            tiers[i] = pricingTiers[phase.tierIds[i]];
        }
    }

    /**
     * @dev Activate a phase
     * @param phaseId Target phase ID
     */
    function activatePhase(uint256 phaseId) external onlyRole(SALE_MANAGER_ROLE) {
        if (phaseId >= currentPhaseId) revert InvalidPhase(phaseId);

        salePhases[phaseId].isActive = true;
        emit PhaseActivated(phaseId);
    }

    /**
     * @dev Deactivate a phase
     * @param phaseId Target phase ID
     */
    function deactivatePhase(uint256 phaseId) external onlyRole(SALE_MANAGER_ROLE) {
        if (phaseId >= currentPhaseId) revert InvalidPhase(phaseId);

        salePhases[phaseId].isActive = false;
        emit PhaseDeactivated(phaseId);
    }

    /**
     * @dev Update platform fee rate
     * @param newFeeRate New fee rate in basis points
     */
    function setPlatformFeeRate(uint256 newFeeRate) external onlyRole(PLATFORM_ADMIN_ROLE) {
        newFeeRate.validateBasisPoints("platform fee rate");
        platformFeeRate = newFeeRate;
    }

    /**
     * @dev Withdraw accumulated revenue
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function withdrawRevenue(address to, uint256 amount) external onlyRole(PLATFORM_ADMIN_ROLE) {
        to.validateAddress("withdrawal recipient");
        amount.validateAmount(1, address(this).balance, "withdrawal amount");

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed(to, amount);

        emit RevenueWithdrawn(to, amount);
    }

    /**
     * @dev Emergency pause
     */
    function pause() external onlyRole(PLATFORM_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Emergency unpause
     */
    function unpause() external onlyRole(PLATFORM_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Get contract balance
     * @return Contract balance in wei
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Get total phases created
     * @return Number of phases created
     */
    function getTotalPhases() external view returns (uint256) {
        return currentPhaseId;
    }

    /**
     * @dev Get total purchases made
     * @return Number of purchases made
     */
    function getTotalPurchases() external view returns (uint256) {
        return nextPurchaseId;
    }
}