// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./Utils/Security/TuuKeepAccessControl.sol";
import "./Utils/Security/TuuKeepReentrancyGuard.sol";
import "./Utils/Security/ValidationLib.sol";
import "./Utils/TuuKeepErrors.sol";
import "./interfaces/ITuuKeepCabinetCore.sol";

/**
 * @title TuuKeepMarketplace
 * @dev Basic P2P marketplace for TuuKeep Cabinet NFTs with fixed-price listings only
 * @notice Enables cabinet owners to list their NFTs for sale and buyers to purchase directly
 */
contract TuuKeepMarketplace is
    AccessControl,
    Pausable,
    TuuKeepReentrancyGuard
{
    // Access control roles
    bytes32 public constant MARKETPLACE_ADMIN_ROLE = keccak256("MARKETPLACE_ADMIN_ROLE");
    bytes32 public constant EMERGENCY_RESPONDER_ROLE = keccak256("EMERGENCY_RESPONDER_ROLE");

    // Contract integrations
    ITuuKeepCabinetCore public immutable cabinetContract;
    TuuKeepAccessControl public immutable accessControl;

    // Core marketplace structures
    struct Listing {
        uint256 cabinetId;          // Cabinet NFT token ID
        address seller;             // Cabinet owner/seller
        uint256 price;              // Fixed listing price in wei
        uint256 createdAt;          // Listing creation timestamp
        uint256 expiresAt;          // Listing expiration timestamp
        bool isActive;              // Simple active/inactive flag
    }

    struct MarketplaceConfig {
        uint256 platformFeeRate;    // Platform fee in basis points (500 = 5%)
        address feeRecipient;       // Platform fee recipient
        uint256 minListingDuration; // Minimum listing duration (24 hours)
        uint256 maxListingDuration; // Maximum listing duration (30 days)
        uint256 minPrice;           // Minimum listing price (0.001 KUB)
    }

    struct MarketSummary {
        uint256 totalActiveListings;
        uint256 totalVolume24h;
        uint256 averagePrice24h;
        uint256 totalSales;
    }

    // State variables
    mapping(uint256 => Listing) public listings;              // Listing ID to listing
    mapping(uint256 => uint256) public cabinetToListing;      // Cabinet ID to active listing ID
    mapping(address => uint256[]) public userListings;        // User to their listing IDs

    uint256 private _listingIdCounter;
    MarketplaceConfig public config;

    // Analytics tracking
    uint256 public totalVolume;
    uint256 public totalSales;
    mapping(uint256 => uint256) public dailyVolume;          // Day timestamp to volume
    mapping(uint256 => uint256) public dailySales;           // Day timestamp to sales count

    // Constants
    uint256 public constant DEFAULT_PLATFORM_FEE_RATE = 500; // 5%
    uint256 public constant MAX_PLATFORM_FEE_RATE = 1000;    // 10%
    uint256 public constant MIN_LISTING_DURATION = 1 days;
    uint256 public constant MAX_LISTING_DURATION = 30 days;
    uint256 public constant MIN_LISTING_PRICE = 0.001 ether;

    // Events
    event ListingCreated(
        uint256 indexed listingId,
        uint256 indexed cabinetId,
        address indexed seller,
        uint256 price,
        uint256 expiresAt
    );

    event ListingCancelled(
        uint256 indexed listingId,
        uint256 indexed cabinetId,
        address indexed seller
    );

    event ListingPriceUpdated(
        uint256 indexed listingId,
        uint256 indexed cabinetId,
        uint256 oldPrice,
        uint256 newPrice
    );

    event CabinetSold(
        uint256 indexed listingId,
        uint256 indexed cabinetId,
        address indexed seller,
        address buyer,
        uint256 price,
        uint256 platformFee
    );

    event MarketplaceConfigUpdated(
        uint256 platformFeeRate,
        address feeRecipient,
        uint256 minListingDuration,
        uint256 maxListingDuration,
        uint256 minPrice
    );

    // Custom errors extending TuuKeepErrors.sol patterns
    error ListingNotFound(uint256 listingId);
    error ListingNotActive(uint256 listingId);
    error ListingExpired(uint256 listingId);
    error CabinetAlreadyListed(uint256 cabinetId, uint256 existingListingId);
    error InsufficientPayment(uint256 required, uint256 provided);
    error UnauthorizedCabinetAccess(uint256 cabinetId, address caller);
    error UnauthorizedListingAccess(uint256 listingId, address caller);
    error InvalidListingPrice(uint256 price, uint256 minPrice);
    error InvalidListingDuration(uint256 duration, uint256 minDuration, uint256 maxDuration);
    error CannotBuyOwnListing(uint256 listingId, address caller);
    error CabinetNotApproved(uint256 cabinetId, address marketplace);

    // Modifiers
    modifier onlyCabinetOwner(uint256 cabinetId) {
        if (cabinetContract.ownerOf(cabinetId) != msg.sender) {
            revert UnauthorizedCabinetAccess(cabinetId, msg.sender);
        }
        _;
    }

    modifier onlyListingSeller(uint256 listingId) {
        if (listings[listingId].seller != msg.sender) {
            revert UnauthorizedListingAccess(listingId, msg.sender);
        }
        _;
    }

    modifier validListing(uint256 listingId) {
        Listing storage listing = listings[listingId];
        if (!listing.isActive) {
            revert ListingNotActive(listingId);
        }
        if (block.timestamp > listing.expiresAt) {
            revert ListingExpired(listingId);
        }
        _;
    }

    modifier listingExists(uint256 listingId) {
        if (listings[listingId].seller == address(0)) {
            revert ListingNotFound(listingId);
        }
        _;
    }

    /**
     * @dev Constructor
     * @param _cabinetContract Address of the TuuKeepCabinet contract
     * @param _accessControl Address of the TuuKeepAccessControl contract
     * @param _platformFeeRecipient Address to receive platform fees
     */
    constructor(
        address _cabinetContract,
        address _accessControl,
        address _platformFeeRecipient
    ) {
        ValidationLib.validateAddress(_cabinetContract, "cabinet contract");
        ValidationLib.validateAddress(_accessControl, "access control");
        ValidationLib.validateAddress(_platformFeeRecipient, "platform fee recipient");

        cabinetContract = ITuuKeepCabinetCore(_cabinetContract);
        accessControl = TuuKeepAccessControl(_accessControl);

        // Initialize marketplace configuration
        config = MarketplaceConfig({
            platformFeeRate: DEFAULT_PLATFORM_FEE_RATE,
            feeRecipient: _platformFeeRecipient,
            minListingDuration: MIN_LISTING_DURATION,
            maxListingDuration: MAX_LISTING_DURATION,
            minPrice: MIN_LISTING_PRICE
        });

        // Grant admin role to deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MARKETPLACE_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Create a new fixed-price listing for a cabinet NFT
     * @param cabinetId The ID of the cabinet to list
     * @param price The listing price in wei
     * @param duration The listing duration in seconds
     * @return listingId The ID of the created listing
     */
    function createListing(
        uint256 cabinetId,
        uint256 price,
        uint256 duration
    )
        external
        onlyCabinetOwner(cabinetId)
        nonReentrant
        whenNotPaused
        returns (uint256 listingId)
    {
        // Validate inputs
        if (price < config.minPrice) {
            revert InvalidListingPrice(price, config.minPrice);
        }
        if (duration < config.minListingDuration || duration > config.maxListingDuration) {
            revert InvalidListingDuration(duration, config.minListingDuration, config.maxListingDuration);
        }

        // Check if cabinet is already listed
        uint256 existingListingId = cabinetToListing[cabinetId];
        if (existingListingId != 0 && listings[existingListingId].isActive) {
            revert CabinetAlreadyListed(cabinetId, existingListingId);
        }

        // Verify cabinet is approved for marketplace
        if (cabinetContract.getApproved(cabinetId) != address(this) &&
            !cabinetContract.isApprovedForAll(msg.sender, address(this))) {
            revert CabinetNotApproved(cabinetId, address(this));
        }

        // Create new listing
        listingId = ++_listingIdCounter;
        uint256 expiresAt = block.timestamp + duration;

        listings[listingId] = Listing({
            cabinetId: cabinetId,
            seller: msg.sender,
            price: price,
            createdAt: block.timestamp,
            expiresAt: expiresAt,
            isActive: true
        });

        // Update mappings
        cabinetToListing[cabinetId] = listingId;
        userListings[msg.sender].push(listingId);

        emit ListingCreated(listingId, cabinetId, msg.sender, price, expiresAt);
    }

    /**
     * @dev Cancel an active listing
     * @param listingId The ID of the listing to cancel
     */
    function cancelListing(
        uint256 listingId
    )
        external
        onlyListingSeller(listingId)
        listingExists(listingId)
        nonReentrant
    {
        Listing storage listing = listings[listingId];

        if (!listing.isActive) {
            revert ListingNotActive(listingId);
        }

        // Deactivate listing
        listing.isActive = false;

        // Clear cabinet mapping
        delete cabinetToListing[listing.cabinetId];

        emit ListingCancelled(listingId, listing.cabinetId, listing.seller);
    }

    /**
     * @dev Update the price of an active listing
     * @param listingId The ID of the listing to update
     * @param newPrice The new listing price in wei
     */
    function updateListingPrice(
        uint256 listingId,
        uint256 newPrice
    )
        external
        onlyListingSeller(listingId)
        listingExists(listingId)
        validListing(listingId)
        nonReentrant
    {
        if (newPrice < config.minPrice) {
            revert InvalidListingPrice(newPrice, config.minPrice);
        }

        Listing storage listing = listings[listingId];
        uint256 oldPrice = listing.price;
        listing.price = newPrice;

        emit ListingPriceUpdated(listingId, listing.cabinetId, oldPrice, newPrice);
    }

    /**
     * @dev Purchase a cabinet from an active listing
     * @param listingId The ID of the listing to purchase
     */
    function buyNow(
        uint256 listingId
    )
        external
        payable
        listingExists(listingId)
        validListing(listingId)
        nonReentrant
        whenNotPaused
    {
        Listing storage listing = listings[listingId];

        // Prevent self-purchase
        if (listing.seller == msg.sender) {
            revert CannotBuyOwnListing(listingId, msg.sender);
        }

        // Validate payment amount
        if (msg.value < listing.price) {
            revert InsufficientPayment(listing.price, msg.value);
        }

        // Process payment and fees
        (uint256 platformFee, uint256 sellerAmount) = _processPayment(listing.price);

        // Transfer cabinet NFT
        _transferCabinet(listing.cabinetId, listing.seller, msg.sender);

        // Distribute payments
        _distributeFees(listing.seller, sellerAmount, platformFee);

        // Handle overpayment refund
        uint256 overpayment = msg.value - listing.price;
        if (overpayment > 0) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: overpayment}("");
            require(refundSuccess, "Overpayment refund failed");
        }

        // Update analytics
        _updateMarketAnalytics(listing.price);

        // Deactivate listing
        listing.isActive = false;
        delete cabinetToListing[listing.cabinetId];

        emit CabinetSold(
            listingId,
            listing.cabinetId,
            listing.seller,
            msg.sender,
            listing.price,
            platformFee
        );
    }

    /**
     * @dev Process payment calculation for marketplace fees
     * @param salePrice The total sale price
     * @return platformFee The calculated platform fee
     * @return sellerAmount The amount due to the seller
     */
    function _processPayment(
        uint256 salePrice
    ) internal view returns (uint256 platformFee, uint256 sellerAmount) {
        platformFee = (salePrice * config.platformFeeRate) / 10000;
        sellerAmount = salePrice - platformFee;
    }

    /**
     * @dev Transfer cabinet NFT from seller to buyer
     * @param cabinetId The ID of the cabinet to transfer
     * @param from The current owner (seller)
     * @param to The new owner (buyer)
     */
    function _transferCabinet(
        uint256 cabinetId,
        address from,
        address to
    ) internal {
        cabinetContract.safeTransferFrom(from, to, cabinetId);
    }

    /**
     * @dev Distribute payment to seller and platform fee recipient
     * @param seller The seller address
     * @param sellerAmount The amount to send to seller
     * @param platformFee The platform fee amount
     */
    function _distributeFees(
        address seller,
        uint256 sellerAmount,
        uint256 platformFee
    ) internal {
        // Transfer to seller
        if (sellerAmount > 0) {
            (bool sellerSuccess, ) = payable(seller).call{value: sellerAmount}("");
            require(sellerSuccess, "Seller payment failed");
        }

        // Transfer platform fee
        if (platformFee > 0) {
            (bool feeSuccess, ) = payable(config.feeRecipient).call{value: platformFee}("");
            require(feeSuccess, "Platform fee payment failed");
        }
    }

    /**
     * @dev Update market analytics tracking
     * @param salePrice The price of the completed sale
     */
    function _updateMarketAnalytics(uint256 salePrice) internal {
        totalVolume += salePrice;
        totalSales += 1;

        // Update daily analytics
        uint256 today = block.timestamp / 1 days;
        dailyVolume[today] += salePrice;
        dailySales[today] += 1;
    }

    /**
     * @dev Get active listing for a specific cabinet
     * @param cabinetId The ID of the cabinet
     * @return listing The active listing details, or empty struct if no active listing
     */
    function getActiveListing(uint256 cabinetId) external view returns (Listing memory listing) {
        uint256 listingId = cabinetToListing[cabinetId];
        if (listingId != 0 && listings[listingId].isActive && block.timestamp <= listings[listingId].expiresAt) {
            listing = listings[listingId];
        }
    }

    /**
     * @dev Get all listing IDs for a specific user
     * @param user The user address
     * @return listingIds Array of listing IDs created by the user
     */
    function getListingsByUser(address user) external view returns (uint256[] memory listingIds) {
        return userListings[user];
    }

    /**
     * @dev Get market summary statistics
     * @return summary Market summary with key metrics
     */
    function getMarketSummary() external view returns (MarketSummary memory summary) {
        uint256 activeListings = 0;

        // Count active listings (simplified approach)
        for (uint256 i = 1; i <= _listingIdCounter; i++) {
            if (listings[i].isActive && block.timestamp <= listings[i].expiresAt) {
                activeListings++;
            }
        }

        uint256 today = block.timestamp / 1 days;

        summary = MarketSummary({
            totalActiveListings: activeListings,
            totalVolume24h: dailyVolume[today],
            averagePrice24h: dailySales[today] > 0 ? dailyVolume[today] / dailySales[today] : 0,
            totalSales: totalSales
        });
    }

    /**
     * @dev Update marketplace configuration (admin only)
     * @param newConfig The new marketplace configuration
     */
    function updateMarketplaceConfig(
        MarketplaceConfig memory newConfig
    ) external onlyRole(MARKETPLACE_ADMIN_ROLE) {
        // Validate configuration
        ValidationLib.validateBasisPoints(newConfig.platformFeeRate, "platform fee rate");
        ValidationLib.validateAddress(newConfig.feeRecipient, "fee recipient");

        if (newConfig.platformFeeRate > MAX_PLATFORM_FEE_RATE) {
            revert TuuKeepErrors.InvalidFeeRate(newConfig.platformFeeRate);
        }

        if (newConfig.minListingDuration == 0 || newConfig.maxListingDuration == 0 ||
            newConfig.minListingDuration >= newConfig.maxListingDuration) {
            revert TuuKeepErrors.InvalidConfiguration("listing duration", "invalid duration range");
        }

        config = newConfig;

        emit MarketplaceConfigUpdated(
            newConfig.platformFeeRate,
            newConfig.feeRecipient,
            newConfig.minListingDuration,
            newConfig.maxListingDuration,
            newConfig.minPrice
        );
    }

    /**
     * @dev Emergency pause a specific listing (emergency responder only)
     * @param listingId The ID of the listing to pause
     */
    function emergencyPauseListing(
        uint256 listingId
    ) external onlyRole(EMERGENCY_RESPONDER_ROLE) listingExists(listingId) {
        Listing storage listing = listings[listingId];
        if (listing.isActive) {
            listing.isActive = false;
            delete cabinetToListing[listing.cabinetId];

            emit ListingCancelled(listingId, listing.cabinetId, listing.seller);
        }
    }

    /**
     * @dev Pause the entire marketplace (admin only)
     */
    function pauseMarketplace() external onlyRole(MARKETPLACE_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the marketplace (admin only)
     */
    function unpauseMarketplace() external onlyRole(MARKETPLACE_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Emergency withdraw function (emergency responder only)
     * @dev Should only be used in extreme circumstances
     */
    function emergencyWithdraw() external onlyRole(EMERGENCY_RESPONDER_ROLE) {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(config.feeRecipient).call{value: balance}("");
            require(success, "Emergency withdrawal failed");
        }
    }

    /**
     * @dev Get current listing counter for external reference
     * @return The current listing ID counter
     */
    function getCurrentListingId() external view returns (uint256) {
        return _listingIdCounter;
    }

    /**
     * @dev Check if marketplace supports a specific interface
     * @param interfaceId The interface identifier
     * @return True if interface is supported
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}