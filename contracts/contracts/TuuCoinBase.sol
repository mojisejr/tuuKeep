// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./Utils/Security/TuuKeepAccessControl.sol";
import "./Utils/Security/ValidationLib.sol";

/**
 * @title TuuCoinBase
 * @dev Base ERC20 token contract for the TuuKeep ecosystem
 * Handles standard token functionality, minting, and basic operations
 */
contract TuuCoinBase is ERC20, ERC20Burnable, AccessControl, Pausable {
    // Access control constants
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PLATFORM_ADMIN_ROLE = keccak256("PLATFORM_ADMIN_ROLE");
    bytes32 public constant EMERGENCY_RESPONDER_ROLE = keccak256("EMERGENCY_RESPONDER_ROLE");

    // Platform integration
    TuuKeepAccessControl public immutable accessControl;

    // Token economics
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 public totalMinted;
    uint256 public totalBurned;

    // Enhanced supply management
    uint256 public adjustableMaxSupply;
    bool public isDynamicSupplyEnabled;

    // Emergency pause controls
    bool public mintingPaused;
    bool public burningPaused;
    bool public transfersPaused;
    mapping(address => string) public pauseReasons;

    // Events
    event TokensMinted(address indexed to, uint256 amount, address indexed minter);
    event AccessControlUpdated(address indexed newAccessControl, address indexed updater);
    event MaxSupplyAdjusted(uint256 oldMaxSupply, uint256 newMaxSupply);
    event DynamicSupplyToggled(bool enabled);
    event EmergencyPauseActivated(address indexed responder, string reason);
    event EmergencyPauseDeactivated(address indexed responder);
    event SelectivePauseActivated(bool minting, bool burning, bool transfers, string reason);
    event SelectivePauseDeactivated(address indexed responder);

    /**
     * @dev Constructor initializes TuuCoinBase with access control integration
     */
    constructor(
        address _accessControl,
        address _initialAdmin
    ) ERC20("TuuCoin", "TUU") {
        ValidationLib.validateConstructorContract(_accessControl, "access control");
        ValidationLib.validateConstructorAddress(_initialAdmin, "initial admin");

        accessControl = TuuKeepAccessControl(_accessControl);
        _initializeRoles(_initialAdmin);
        _initializeSupplyManagement();
    }

    /**
     * @dev Mint tokens to specified address
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(to != address(0), "TuuCoinBase: cannot mint to zero address");
        require(amount > 0, "TuuCoinBase: amount must be greater than zero");
        require(!mintingPaused, "TuuCoinBase: minting is paused");
        require(totalMinted + amount <= getEffectiveMaxSupply(), "TuuCoinBase: would exceed max supply");

        totalMinted += amount;
        _mint(to, amount);

        emit TokensMinted(to, amount, msg.sender);
    }

    /**
     * @dev Batch mint tokens to multiple addresses
     */
    function batchMint(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyRole(MINTER_ROLE) {
        require(recipients.length == amounts.length, "TuuCoinBase: arrays length mismatch");
        require(recipients.length > 0, "TuuCoinBase: empty arrays");
        require(!mintingPaused, "TuuCoinBase: minting is paused");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            require(recipients[i] != address(0), "TuuCoinBase: cannot mint to zero address");
            require(amounts[i] > 0, "TuuCoinBase: amount must be greater than zero");
            totalAmount += amounts[i];
        }

        require(totalMinted + totalAmount <= getEffectiveMaxSupply(), "TuuCoinBase: would exceed max supply");

        totalMinted += totalAmount;

        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
            emit TokensMinted(recipients[i], amounts[i], msg.sender);
        }
    }

    /**
     * @dev Burn tokens and update tracking
     */
    function burn(uint256 amount) public override {
        require(!burningPaused, "TuuCoinBase: burning is paused");
        totalBurned += amount;
        super.burn(amount);
    }

    /**
     * @dev Burn tokens from account and update tracking
     */
    function burnFrom(address account, uint256 amount) public override {
        require(!burningPaused, "TuuCoinBase: burning is paused");
        totalBurned += amount;
        super.burnFrom(account, amount);
    }

    // ============ EMERGENCY PAUSE FUNCTIONS ============

    /**
     * @dev Emergency pause all contract operations
     */
    function emergencyPause(string calldata reason) external onlyRole(EMERGENCY_RESPONDER_ROLE) {
        _pause();
        pauseReasons[msg.sender] = reason;
        emit EmergencyPauseActivated(msg.sender, reason);
    }

    /**
     * @dev Resume all contract operations
     */
    function emergencyUnpause() external onlyRole(EMERGENCY_RESPONDER_ROLE) {
        _unpause();
        emit EmergencyPauseDeactivated(msg.sender);
    }

    /**
     * @dev Pause specific operations
     */
    function selectivePause(
        bool pauseMinting,
        bool pauseBurning,
        bool pauseTransfers,
        string calldata reason
    ) external onlyRole(EMERGENCY_RESPONDER_ROLE) {
        mintingPaused = pauseMinting;
        burningPaused = pauseBurning;
        transfersPaused = pauseTransfers;

        pauseReasons[msg.sender] = reason;
        emit SelectivePauseActivated(pauseMinting, pauseBurning, pauseTransfers, reason);
    }

    /**
     * @dev Resume specific operations
     */
    function selectiveUnpause() external onlyRole(EMERGENCY_RESPONDER_ROLE) {
        mintingPaused = false;
        burningPaused = false;
        transfersPaused = false;
        emit SelectivePauseDeactivated(msg.sender);
    }

    /**
     * @dev Override transfer to respect pause state
     */
    function _update(address from, address to, uint256 value) internal override {
        require(!transfersPaused || from == address(0) || to == address(0), "TuuCoinBase: transfers are paused");
        super._update(from, to, value);
    }

    // ============ ENHANCED SUPPLY MANAGEMENT ============

    /**
     * @dev Enable or disable dynamic supply adjustments
     */
    function setDynamicSupplyEnabled(bool enabled) external onlyRole(PLATFORM_ADMIN_ROLE) {
        isDynamicSupplyEnabled = enabled;
        emit DynamicSupplyToggled(enabled);
    }

    /**
     * @dev Adjust maximum supply (only if dynamic supply is enabled)
     */
    function adjustMaxSupply(uint256 newMaxSupply) external onlyRole(PLATFORM_ADMIN_ROLE) {
        require(isDynamicSupplyEnabled, "TuuCoinBase: dynamic supply not enabled");
        require(newMaxSupply >= totalMinted, "TuuCoinBase: new max supply below current minted");
        require(newMaxSupply <= MAX_SUPPLY * 2, "TuuCoinBase: cannot exceed 2x original max supply");

        uint256 oldMaxSupply = adjustableMaxSupply;
        adjustableMaxSupply = newMaxSupply;

        emit MaxSupplyAdjusted(oldMaxSupply, newMaxSupply);
    }

    /**
     * @dev Get effective maximum supply (considers dynamic adjustments)
     */
    function getEffectiveMaxSupply() public view returns (uint256) {
        return isDynamicSupplyEnabled ? adjustableMaxSupply : MAX_SUPPLY;
    }

    /**
     * @dev Emergency function to update access control contract
     */
    function updateAccessControl(address _newAccessControl)
        external
        onlyRole(PLATFORM_ADMIN_ROLE)
    {
        require(_newAccessControl != address(0), "TuuCoinBase: invalid access control address");
        require(_newAccessControl != address(accessControl), "TuuCoinBase: same access control address");

        emit AccessControlUpdated(_newAccessControl, msg.sender);
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Get current token supply statistics
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

    /**
     * @dev Get pause status information
     */
    function getPauseStatus()
        external
        view
        returns (
            bool isPaused,
            bool mintingPausedStatus,
            bool burningPausedStatus,
            bool transfersPausedStatus
        )
    {
        return (
            paused(),
            mintingPaused,
            burningPaused,
            transfersPaused
        );
    }

    /**
     * @dev Get enhanced supply information
     */
    function getEnhancedSupplyStats()
        external
        view
        returns (
            uint256 currentSupply,
            uint256 effectiveMaxSupply,
            bool isDynamicEnabled,
            uint256 mintedTotal,
            uint256 burnedTotal
        )
    {
        return (
            totalSupply(),
            getEffectiveMaxSupply(),
            isDynamicSupplyEnabled,
            totalMinted,
            totalBurned
        );
    }

    /**
     * @dev Override supportsInterface to include AccessControl
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

    function _initializeRoles(address admin) private {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PLATFORM_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(EMERGENCY_RESPONDER_ROLE, admin);
    }

    function _initializeSupplyManagement() private {
        adjustableMaxSupply = MAX_SUPPLY;
        isDynamicSupplyEnabled = false;
    }

    /**
     * @dev Post-deployment validation to confirm constructor parameters are contracts
     * Call this immediately after deployment to validate access control integration
     */
    function validatePostDeployment() external view {
        address[] memory addresses = new address[](1);
        string[] memory contexts = new string[](1);

        addresses[0] = address(accessControl);
        contexts[0] = "access control";

        ValidationLib.validatePostDeployment(addresses, contexts);
    }
}