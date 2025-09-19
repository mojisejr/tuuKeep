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
 * @title TuuKeepMarketplaceCore
 * @dev Core marketplace functionality for TuuKeep Cabinet NFTs
 * Handles listing creation, cancellation, and purchase transactions
 */
contract TuuKeepMarketplaceCore is
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
    address public marketplaceFeeContract;

    // Core marketplace structures
    struct Listing {
        uint256 cabinetId;
        address seller;
        uint256 price;
        uint256 createdAt;
        uint256 expiresAt;
        bool isActive;
    }

    struct MarketplaceConfig {
        uint256 minListingDuration;
        uint256 maxListingDuration;
        uint256 minPrice;
    }

    // State variables
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => uint256) public cabinetToListing;
    mapping(address => uint256[]) public userListings;

    uint256 private _listingIdCounter;
    MarketplaceConfig public config;

    // Analytics tracking
    uint256 public totalVolume;
    uint256 public totalSales;
    mapping(uint256 => uint256) public dailyVolume;
    mapping(uint256 => uint256) public dailySales;

    // Constants
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

    // Custom errors
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

    constructor(
        address _cabinetContract,
        address _accessControl
    ) {
        ValidationLib.validateAddress(_cabinetContract, "cabinet contract");
        ValidationLib.validateAddress(_accessControl, "access control");

        cabinetContract = ITuuKeepCabinetCore(_cabinetContract);
        accessControl = TuuKeepAccessControl(_accessControl);

        // Initialize marketplace configuration
        config = MarketplaceConfig({
            minListingDuration: MIN_LISTING_DURATION,
            maxListingDuration: MAX_LISTING_DURATION,
            minPrice: MIN_LISTING_PRICE
        });

        // Grant admin role to deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MARKETPLACE_ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_RESPONDER_ROLE, msg.sender);
    }

    /**
     * @dev Set the marketplace fee contract address
     */
    function setMarketplaceFeeContract(address _marketplaceFeeContract)
        external
        onlyRole(MARKETPLACE_ADMIN_ROLE)
    {
        ValidationLib.validateContract(_marketplaceFeeContract, "marketplace fee contract");
        marketplaceFeeContract = _marketplaceFeeContract;
    }

    /**
     * @dev Create a new fixed-price listing for a cabinet NFT
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

        // Process payment and fees through fee contract
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
     * @dev Process payment calculation through fee contract
     */
    function _processPayment(
        uint256 salePrice
    ) internal view returns (uint256 platformFee, uint256 sellerAmount) {
        if (marketplaceFeeContract != address(0)) {
            // Call fee contract to calculate fees
            (bool success, bytes memory data) = marketplaceFeeContract.staticcall(
                abi.encodeWithSignature("calculateFees(uint256)", salePrice)
            );

            if (success) {
                (platformFee, sellerAmount) = abi.decode(data, (uint256, uint256));
            } else {
                // Fallback to no fees if fee contract call fails
                platformFee = 0;
                sellerAmount = salePrice;
            }
        } else {
            // No fee contract, seller gets full amount
            platformFee = 0;
            sellerAmount = salePrice;
        }
    }

    /**
     * @dev Transfer cabinet NFT from seller to buyer
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

        // Transfer platform fee through fee contract
        if (platformFee > 0 && marketplaceFeeContract != address(0)) {
            (bool feeSuccess, ) = marketplaceFeeContract.call{value: platformFee}(
                abi.encodeWithSignature("distributeFee()")
            );
            require(feeSuccess, "Platform fee payment failed");
        }
    }

    /**
     * @dev Update market analytics tracking
     */
    function _updateMarketAnalytics(uint256 salePrice) internal {
        totalVolume += salePrice;
        totalSales += 1;

        // Update daily analytics
        uint256 today = block.timestamp / 1 days;
        dailyVolume[today] += salePrice;
        dailySales[today] += 1;
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Get active listing for a specific cabinet
     */
    function getActiveListing(uint256 cabinetId) external view returns (Listing memory listing) {
        uint256 listingId = cabinetToListing[cabinetId];
        if (listingId != 0 && listings[listingId].isActive && block.timestamp <= listings[listingId].expiresAt) {
            listing = listings[listingId];
        }
    }

    /**
     * @dev Get all listing IDs for a specific user
     */
    function getListingsByUser(address user) external view returns (uint256[] memory listingIds) {
        return userListings[user];
    }

    /**
     * @dev Get current listing counter
     */
    function getCurrentListingId() external view returns (uint256) {
        return _listingIdCounter;
    }

    /**
     * @dev Get marketplace configuration
     */
    function getMarketplaceConfig() external view returns (MarketplaceConfig memory) {
        return config;
    }

    /**
     * @dev Get market analytics
     */
    function getMarketAnalytics() external view returns (uint256 volume, uint256 sales) {
        return (totalVolume, totalSales);
    }

    /**
     * @dev Get daily market data
     */
    function getDailyMarketData(uint256 day) external view returns (uint256 volume, uint256 sales) {
        return (dailyVolume[day], dailySales[day]);
    }

    // ============ ADMINISTRATIVE FUNCTIONS ============

    /**
     * @dev Update marketplace configuration
     */
    function updateMarketplaceConfig(
        MarketplaceConfig memory newConfig
    ) external onlyRole(MARKETPLACE_ADMIN_ROLE) {
        if (newConfig.minListingDuration == 0 || newConfig.maxListingDuration == 0 ||
            newConfig.minListingDuration >= newConfig.maxListingDuration) {
            revert TuuKeepErrors.InvalidConfiguration("listing duration", "invalid duration range");
        }

        config = newConfig;
    }

    /**
     * @dev Emergency pause a specific listing
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
     * @dev Pause the entire marketplace
     */
    function pauseMarketplace() external onlyRole(MARKETPLACE_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the marketplace
     */
    function unpauseMarketplace() external onlyRole(MARKETPLACE_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Check if marketplace supports a specific interface
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}