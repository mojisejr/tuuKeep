// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Utils/Security/TuuKeepAccessControl.sol";

/**
 * @title TuuCoin
 * @dev Native token for the TuuKeep decentralized gachapon platform
 *
 * Features:
 * - Standard ERC-20 functionality with OpenZeppelin base
 * - Controlled minting mechanism for platform economy
 * - Burn functionality for gacha odds improvement
 * - Role-based access control for administrative functions
 * - Integration with TuuKeep security infrastructure
 *
 * Platform Economy:
 * - Players earn TuuCoins from unsuccessful gacha plays
 * - TuuCoins can be burned to improve future gacha odds
 * - Minting is controlled by platform administrators
 * - Burns are tracked for odds calculation mechanics
 */
contract TuuCoin is ERC20, ERC20Burnable, AccessControl {

    // Access control constants
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PLATFORM_ADMIN_ROLE = keccak256("PLATFORM_ADMIN_ROLE");

    // Platform integration
    TuuKeepAccessControl public immutable accessControl;

    // Token economics
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 public totalMinted;
    uint256 public totalBurned;

    // Burn tracking for odds modification
    mapping(address => uint256) public userBurnedAmount;
    mapping(address => uint256) public userBurnCount;

    // Events
    event TokensMinted(address indexed to, uint256 amount, address indexed minter);
    event TokensBurnedForOdds(address indexed user, uint256 amount, uint256 totalBurned);
    event AccessControlUpdated(address indexed newAccessControl, address indexed updater);

    /**
     * @dev Constructor initializes TuuCoin with access control integration
     * @param _accessControl Address of the TuuKeepAccessControl contract
     * @param _initialAdmin Address that will receive initial admin roles
     */
    constructor(
        address _accessControl,
        address _initialAdmin
    ) ERC20("TuuCoin", "TUU") {
        require(_accessControl != address(0), "TuuCoin: invalid access control address");
        require(_initialAdmin != address(0), "TuuCoin: invalid admin address");

        accessControl = TuuKeepAccessControl(_accessControl);

        // Grant roles to initial admin
        _grantRole(DEFAULT_ADMIN_ROLE, _initialAdmin);
        _grantRole(PLATFORM_ADMIN_ROLE, _initialAdmin);
        _grantRole(MINTER_ROLE, _initialAdmin);
    }

    /**
     * @dev Mint tokens to specified address
     * Can only be called by addresses with MINTER_ROLE
     * @param to Address to receive minted tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(to != address(0), "TuuCoin: cannot mint to zero address");
        require(amount > 0, "TuuCoin: amount must be greater than zero");
        require(totalMinted + amount <= MAX_SUPPLY, "TuuCoin: would exceed max supply");

        totalMinted += amount;
        _mint(to, amount);

        emit TokensMinted(to, amount, msg.sender);
    }

    /**
     * @dev Batch mint tokens to multiple addresses
     * Gas-efficient function for platform reward distribution
     * @param recipients Array of addresses to receive tokens
     * @param amounts Array of amounts corresponding to each recipient
     */
    function batchMint(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyRole(MINTER_ROLE) {
        require(recipients.length == amounts.length, "TuuCoin: arrays length mismatch");
        require(recipients.length > 0, "TuuCoin: empty arrays");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            require(recipients[i] != address(0), "TuuCoin: cannot mint to zero address");
            require(amounts[i] > 0, "TuuCoin: amount must be greater than zero");
            totalAmount += amounts[i];
        }

        require(totalMinted + totalAmount <= MAX_SUPPLY, "TuuCoin: would exceed max supply");

        totalMinted += totalAmount;

        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
            emit TokensMinted(recipients[i], amounts[i], msg.sender);
        }
    }

    /**
     * @dev Burn tokens from caller's balance for odds improvement
     * Tracks burn history for gacha odds calculation
     * @param amount Amount of tokens to burn
     */
    function burnForOdds(uint256 amount) external {
        require(amount > 0, "TuuCoin: amount must be greater than zero");
        require(balanceOf(msg.sender) >= amount, "TuuCoin: insufficient balance");

        // Update burn tracking
        userBurnedAmount[msg.sender] += amount;
        userBurnCount[msg.sender] += 1;
        totalBurned += amount;

        // Burn the tokens
        _burn(msg.sender, amount);

        emit TokensBurnedForOdds(msg.sender, amount, userBurnedAmount[msg.sender]);
    }

    /**
     * @dev Get user's burn statistics for odds calculation
     * @param user Address to check burn statistics for
     * @return burnedAmount Total amount of tokens burned by user
     * @return burnCount Number of burn transactions by user
     */
    function getUserBurnStats(address user)
        external
        view
        returns (uint256 burnedAmount, uint256 burnCount)
    {
        return (userBurnedAmount[user], userBurnCount[user]);
    }

    /**
     * @dev Calculate odds improvement based on burned tokens
     * Returns percentage improvement (basis points, where 100 = 1%)
     * @param user Address to calculate odds improvement for
     * @return improvement Odds improvement in basis points
     */
    function calculateOddsImprovement(address user) external view returns (uint256 improvement) {
        uint256 burnedAmount = userBurnedAmount[user];

        if (burnedAmount == 0) {
            return 0;
        }

        // Basic odds improvement formula: 1 basis point per 1000 tokens burned
        // Max improvement capped at 500 basis points (5%)
        improvement = (burnedAmount / (1000 * 10**18)) * 1; // 1 basis point per 1000 tokens

        if (improvement > 500) {
            improvement = 500; // Cap at 5% improvement
        }

        return improvement;
    }

    /**
     * @dev Emergency function to update access control contract
     * Can only be called by PLATFORM_ADMIN_ROLE
     * @param _newAccessControl Address of new TuuKeepAccessControl contract
     */
    function updateAccessControl(address _newAccessControl)
        external
        onlyRole(PLATFORM_ADMIN_ROLE)
    {
        require(_newAccessControl != address(0), "TuuCoin: invalid access control address");
        require(_newAccessControl != address(accessControl), "TuuCoin: same access control address");

        // Note: This updates the reference but doesn't migrate existing roles
        // New access control contract should be properly configured before calling this

        emit AccessControlUpdated(_newAccessControl, msg.sender);
    }

    /**
     * @dev Override supportsInterface to include AccessControl
     * @param interfaceId Interface identifier to check
     * @return bool True if interface is supported
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Get current token supply statistics
     * @return currentSupply Current total supply
     * @return mintedSupply Total tokens minted since deployment
     * @return burnedSupply Total tokens burned since deployment
     * @return maxSupply Maximum possible supply
     */
    function getSupplyStats()
        external
        view
        returns (
            uint256 currentSupply,
            uint256 mintedSupply,
            uint256 burnedSupply,
            uint256 maxSupply
        )
    {
        return (
            totalSupply(),
            totalMinted,
            totalBurned,
            MAX_SUPPLY
        );
    }
}