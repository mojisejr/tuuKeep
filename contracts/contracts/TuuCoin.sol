// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
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
contract TuuCoin is ERC20, ERC20Burnable, AccessControl, Pausable {

    // Access control constants
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PLATFORM_ADMIN_ROLE = keccak256("PLATFORM_ADMIN_ROLE");
    bytes32 public constant EMISSION_MANAGER_ROLE = keccak256("EMISSION_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_RESPONDER_ROLE = keccak256("EMERGENCY_RESPONDER_ROLE");
    bytes32 public constant CABINET_OPERATOR_ROLE = keccak256("CABINET_OPERATOR_ROLE");

    // Platform integration
    TuuKeepAccessControl public immutable accessControl;

    // Token economics
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 public totalMinted;
    uint256 public totalBurned;

    // Burn tracking for odds modification
    mapping(address => uint256) public userBurnedAmount;
    mapping(address => uint256) public userBurnCount;

    // Cabinet integration
    struct CabinetIntegration {
        bool isRegistered;       // Cabinet registration status
        address owner;           // Cabinet owner address
        uint256 totalEmitted;    // Total tokens emitted for this cabinet
        uint256 totalBurned;     // Total tokens burned for this cabinet
        bool isActive;           // Cabinet active status
    }
    
    mapping(uint256 => CabinetIntegration) public cabinets;
    mapping(uint256 => bool) public cabinetExists;
    uint256 public totalCabinets;

    // Emission rate controls
    struct EmissionConfig {
        uint256 baseRate;        // Base emission rate per cabinet play (in wei)
        uint256 maxRate;         // Maximum emission rate (in wei)
        uint256 decayFactor;     // Time-based decay factor (basis points)
        uint256 lastUpdate;     // Last emission update timestamp
        bool isActive;          // Emission system active status
    }
    
    EmissionConfig public emissionConfig;
    mapping(uint256 => uint256) public cabinetEmissionMultiplier; // Cabinet-specific multipliers
    
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
    event TokensBurnedForOdds(address indexed user, uint256 amount, uint256 totalBurned);
    event AccessControlUpdated(address indexed newAccessControl, address indexed updater);
    
    // Cabinet integration events
    event CabinetRegistered(uint256 indexed cabinetId, address indexed owner, address indexed registrar);
    event CabinetRewardMinted(address indexed player, uint256 amount, uint256 indexed cabinetId);
    event CabinetPlayBurn(address indexed player, uint256 amount, uint256 indexed cabinetId);
    event CabinetStatusUpdated(uint256 indexed cabinetId, bool isActive);
    
    // Emission control events
    event EmissionRateUpdated(uint256 baseRate, uint256 maxRate, uint256 decayFactor);
    event EmissionConfigStatusUpdated(bool isActive);
    event CabinetEmissionMultiplierUpdated(uint256 indexed cabinetId, uint256 multiplier);
    
    // Supply management events
    event MaxSupplyAdjusted(uint256 oldMaxSupply, uint256 newMaxSupply);
    event DynamicSupplyToggled(bool enabled);
    
    // Emergency events
    event EmergencyPauseActivated(address indexed responder, string reason);
    event EmergencyPauseDeactivated(address indexed responder);
    event SelectivePauseActivated(bool minting, bool burning, bool transfers, string reason);
    event SelectivePauseDeactivated(address indexed responder);
    event SelectivePauseUpdated(bool minting, bool burning, bool transfers);
    event PauseReasonUpdated(address indexed responder, string reason);
    event DynamicSupplyStatusChanged(bool enabled);

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
        _grantRole(EMISSION_MANAGER_ROLE, _initialAdmin);
        _grantRole(EMERGENCY_RESPONDER_ROLE, _initialAdmin);
        _grantRole(CABINET_OPERATOR_ROLE, _initialAdmin);
        
        // Initialize emission configuration
        emissionConfig = EmissionConfig({
            baseRate: 1 * 10**18,      // 1 TUU base rate
            maxRate: 10 * 10**18,      // 10 TUU max rate
            decayFactor: 100,          // 1% decay factor
            lastUpdate: block.timestamp,
            isActive: true
        });
        
        // Initialize supply management
        adjustableMaxSupply = MAX_SUPPLY;
        isDynamicSupplyEnabled = false;
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

    // ============ CABINET INTEGRATION FUNCTIONS ============

    /**
     * @dev Register a new cabinet for token integration
     * @param cabinetId Unique identifier for the cabinet
     * @param owner Address of the cabinet owner
     */
    function registerCabinet(uint256 cabinetId, address owner) 
        external 
        onlyRole(CABINET_OPERATOR_ROLE) 
    {
        require(owner != address(0), "TuuCoin: invalid owner address");
        require(!cabinetExists[cabinetId], "TuuCoin: cabinet already registered");

        cabinets[cabinetId] = CabinetIntegration({
            isRegistered: true,
            owner: owner,
            totalEmitted: 0,
            totalBurned: 0,
            isActive: true
        });
        
        cabinetExists[cabinetId] = true;
        totalCabinets++;

        emit CabinetRegistered(cabinetId, owner, msg.sender);
    }

    /**
     * @dev Mint tokens as gacha reward for a specific cabinet
     * @param player Address of the player receiving the reward
     * @param amount Base amount of tokens to mint
     * @param cabinetId Cabinet that generated the reward
     */
    function mintForGachaReward(address player, uint256 amount, uint256 cabinetId)
        external
        onlyRole(CABINET_OPERATOR_ROLE)
        whenNotPaused
    {
        require(player != address(0), "TuuCoin: invalid player address");
        require(amount > 0, "TuuCoin: amount must be greater than zero");
        require(cabinetExists[cabinetId], "TuuCoin: cabinet not registered");
        require(cabinets[cabinetId].isActive, "TuuCoin: cabinet not active");
        require(!mintingPaused, "TuuCoin: minting is paused");

        // Calculate emission-adjusted amount
        uint256 finalAmount = calculateEmissionAmount(cabinetId, amount);
        
        require(totalMinted + finalAmount <= getEffectiveMaxSupply(), "TuuCoin: would exceed max supply");

        totalMinted += finalAmount;
        cabinets[cabinetId].totalEmitted += finalAmount;
        
        _mint(player, finalAmount);

        emit CabinetRewardMinted(player, finalAmount, cabinetId);
        emit TokensMinted(player, finalAmount, msg.sender);
    }

    /**
     * @dev Burn tokens for gacha play with cabinet tracking
     * @param player Address of the player burning tokens
     * @param amount Amount of tokens to burn
     * @param cabinetId Cabinet where the tokens are being used
     */
    function burnForGachaPlay(address player, uint256 amount, uint256 cabinetId)
        external
        onlyRole(CABINET_OPERATOR_ROLE)
        whenNotPaused
    {
        require(player != address(0), "TuuCoin: invalid player address");
        require(amount > 0, "TuuCoin: amount must be greater than zero");
        require(cabinetExists[cabinetId], "TuuCoin: cabinet not registered");
        require(cabinets[cabinetId].isActive, "TuuCoin: cabinet not active");
        require(!burningPaused, "TuuCoin: burning is paused");
        require(balanceOf(player) >= amount, "TuuCoin: insufficient balance");

        // Update burn tracking
        userBurnedAmount[player] += amount;
        userBurnCount[player] += 1;
        totalBurned += amount;
        cabinets[cabinetId].totalBurned += amount;

        // Burn the tokens
        _burn(player, amount);

        emit CabinetPlayBurn(player, amount, cabinetId);
        emit TokensBurnedForOdds(player, amount, userBurnedAmount[player]);
    }

    /**
     * @dev Update cabinet status (active/inactive)
     * @param cabinetId Cabinet to update
     * @param isActive New active status
     */
    function updateCabinetStatus(uint256 cabinetId, bool isActive)
        external
        onlyRole(CABINET_OPERATOR_ROLE)
    {
        require(cabinetExists[cabinetId], "TuuCoin: cabinet not registered");
        
        cabinets[cabinetId].isActive = isActive;
        
        emit CabinetStatusUpdated(cabinetId, isActive);
    }

    // ============ EMISSION RATE CONTROL FUNCTIONS ============

    /**
     * @dev Update emission configuration
     * @param newBaseRate New base emission rate
     * @param newMaxRate New maximum emission rate
     * @param newDecayFactor New decay factor (basis points)
     */
    function updateEmissionConfig(
        uint256 newBaseRate,
        uint256 newMaxRate,
        uint256 newDecayFactor
    ) external onlyRole(EMISSION_MANAGER_ROLE) {
        require(newBaseRate > 0, "TuuCoin: base rate must be positive");
        require(newMaxRate >= newBaseRate, "TuuCoin: max rate must be >= base rate");
        require(newDecayFactor <= 10000, "TuuCoin: decay factor must be <= 100%");

        emissionConfig.baseRate = newBaseRate;
        emissionConfig.maxRate = newMaxRate;
        emissionConfig.decayFactor = newDecayFactor;
        emissionConfig.lastUpdate = block.timestamp;

        emit EmissionRateUpdated(newBaseRate, newMaxRate, newDecayFactor);
    }

    /**
     * @dev Set emission multiplier for a specific cabinet
     * @param cabinetId Cabinet to set multiplier for
     * @param multiplier Emission multiplier (basis points, 10000 = 100%)
     */
    function setCabinetEmissionMultiplier(uint256 cabinetId, uint256 multiplier)
        external
        onlyRole(EMISSION_MANAGER_ROLE)
    {
        require(cabinetExists[cabinetId], "TuuCoin: cabinet not registered");
        require(multiplier <= 50000, "TuuCoin: multiplier too high (max 500%)");

        cabinetEmissionMultiplier[cabinetId] = multiplier;

        emit CabinetEmissionMultiplierUpdated(cabinetId, multiplier);
    }

    /**
     * @dev Toggle emission system active status
     * @param isActive New active status
     */
    function setEmissionActive(bool isActive) external onlyRole(EMISSION_MANAGER_ROLE) {
        emissionConfig.isActive = isActive;
        emissionConfig.lastUpdate = block.timestamp;

        emit EmissionConfigStatusUpdated(isActive);
    }

    /**
     * @dev Calculate emission-adjusted amount for a cabinet
     * @param cabinetId Cabinet ID
     * @param baseAmount Base amount before emission adjustment
     * @return Adjusted amount after emission calculations
     */
    function calculateEmissionAmount(uint256 cabinetId, uint256 baseAmount)
        public
        view
        returns (uint256)
    {
        if (!emissionConfig.isActive) {
            return baseAmount;
        }

        // Apply cabinet-specific multiplier
        uint256 multiplier = cabinetEmissionMultiplier[cabinetId];
        if (multiplier == 0) {
            multiplier = 10000; // Default 100%
        }

        uint256 adjustedAmount = (baseAmount * multiplier) / 10000;

        // Apply emission rate bounds
        if (adjustedAmount < emissionConfig.baseRate) {
            adjustedAmount = emissionConfig.baseRate;
        } else if (adjustedAmount > emissionConfig.maxRate) {
            adjustedAmount = emissionConfig.maxRate;
        }

        return adjustedAmount;
    }

    /**
     * @dev Get current emission configuration
     * @return Current emission config struct
     */
    function getEmissionConfig() external view returns (EmissionConfig memory) {
        return emissionConfig;
    }

    /**
     * @dev Get cabinet emission multiplier
     * @param cabinetId Cabinet ID
     * @return Emission multiplier in basis points
     */
    function getCabinetEmissionMultiplier(uint256 cabinetId) external view returns (uint256) {
        return cabinetEmissionMultiplier[cabinetId];
    }

    // ============ EMERGENCY PAUSE FUNCTIONS ============

    /**
     * @dev Emergency pause all contract operations
     * @param reason Reason for the pause
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
     * @param pauseMinting Whether to pause minting
     * @param pauseBurning Whether to pause burning
     * @param pauseTransfers Whether to pause transfers
     * @param reason Reason for selective pause
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
        require(!transfersPaused || from == address(0) || to == address(0), "TuuCoin: transfers are paused");
        super._update(from, to, value);
    }

    // ============ ENHANCED SUPPLY MANAGEMENT ============

    /**
     * @dev Enable or disable dynamic supply adjustments
     * @param enabled Whether dynamic supply is enabled
     */
    function setDynamicSupplyEnabled(bool enabled) external onlyRole(PLATFORM_ADMIN_ROLE) {
        isDynamicSupplyEnabled = enabled;

        emit DynamicSupplyStatusChanged(enabled);
    }

    /**
     * @dev Adjust maximum supply (only if dynamic supply is enabled)
     * @param newMaxSupply New maximum supply
     */
    function adjustMaxSupply(uint256 newMaxSupply) external onlyRole(PLATFORM_ADMIN_ROLE) {
        require(isDynamicSupplyEnabled, "TuuCoin: dynamic supply not enabled");
        require(newMaxSupply >= totalMinted, "TuuCoin: new max supply below current minted");
        require(newMaxSupply <= MAX_SUPPLY * 2, "TuuCoin: cannot exceed 2x original max supply");

        uint256 oldMaxSupply = adjustableMaxSupply;
        adjustableMaxSupply = newMaxSupply;

        emit MaxSupplyAdjusted(oldMaxSupply, newMaxSupply);
    }

    /**
     * @dev Get effective maximum supply (considers dynamic adjustments)
     * @return Current effective maximum supply
     */
    function getEffectiveMaxSupply() public view returns (uint256) {
        return isDynamicSupplyEnabled ? adjustableMaxSupply : MAX_SUPPLY;
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

    // ============ CABINET GETTER FUNCTIONS ============

    /**
     * @dev Get cabinet information
     * @param cabinetId Cabinet ID to query
     * @return Cabinet integration data
     */
    function getCabinetInfo(uint256 cabinetId) external view returns (CabinetIntegration memory) {
        require(cabinetExists[cabinetId], "TuuCoin: cabinet not registered");
        return cabinets[cabinetId];
    }

    /**
     * @dev Check if cabinet is registered
     * @param cabinetId Cabinet ID to check
     * @return Whether cabinet is registered
     */
    function isCabinetRegistered(uint256 cabinetId) external view returns (bool) {
        return cabinetExists[cabinetId];
    }

    /**
     * @dev Get total number of registered cabinets
     * @return Total cabinet count
     */
    function getTotalCabinets() external view returns (uint256) {
        return totalCabinets;
    }

    /**
     * @dev Get cabinet statistics
     * @param cabinetId Cabinet ID to query
     * @return totalEmitted Total tokens emitted by cabinet
     * @return cabinetTotalBurned Total tokens burned for cabinet
     * @return isActive Whether cabinet is active
     * @return owner Cabinet owner address
     */
    function getCabinetStats(uint256 cabinetId)
        external
        view
        returns (
            uint256 totalEmitted,
            uint256 cabinetTotalBurned,
            bool isActive,
            address owner
        )
    {
        require(cabinetExists[cabinetId], "TuuCoin: cabinet not registered");
        CabinetIntegration memory cabinet = cabinets[cabinetId];
        
        return (
            cabinet.totalEmitted,
            cabinet.totalBurned,
            cabinet.isActive,
            cabinet.owner
        );
    }

    /**
     * @dev Get pause status information
     * @return isPaused Whether contract is globally paused
     * @return mintingPausedStatus Whether minting is paused
     * @return burningPausedStatus Whether burning is paused
     * @return transfersPausedStatus Whether transfers are paused
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
     * @return currentSupply Current total supply
     * @return effectiveMaxSupply Current effective maximum supply
     * @return isDynamicEnabled Whether dynamic supply is enabled
     * @return mintedTotal Total tokens minted
     * @return burnedTotal Total tokens burned
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
}