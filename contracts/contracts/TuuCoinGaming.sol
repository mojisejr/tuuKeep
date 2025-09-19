// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./Utils/Security/TuuKeepAccessControl.sol";

/**
 * @title TuuCoinGaming
 * @dev Gaming features contract for TuuCoin ecosystem
 * Handles cabinet integration, emission control, and odds improvement
 */
contract TuuCoinGaming is AccessControl, Pausable {
    // Access control constants
    bytes32 public constant EMISSION_MANAGER_ROLE = keccak256("EMISSION_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_RESPONDER_ROLE = keccak256("EMERGENCY_RESPONDER_ROLE");
    bytes32 public constant CABINET_OPERATOR_ROLE = keccak256("CABINET_OPERATOR_ROLE");
    bytes32 public constant PLATFORM_ADMIN_ROLE = keccak256("PLATFORM_ADMIN_ROLE");

    // Platform integration
    TuuKeepAccessControl public immutable accessControl;
    address public tuuCoinBaseContract;

    // Burn tracking for odds modification
    mapping(address => uint256) public userBurnedAmount;
    mapping(address => uint256) public userBurnCount;
    uint256 public totalGamingBurned;

    // Cabinet integration
    struct CabinetIntegration {
        bool isRegistered;
        address owner;
        uint256 totalEmitted;
        uint256 totalBurned;
        bool isActive;
    }

    mapping(uint256 => CabinetIntegration) public cabinets;
    mapping(uint256 => bool) public cabinetExists;
    uint256 public totalCabinets;

    // Emission rate controls
    struct EmissionConfig {
        uint256 baseRate;
        uint256 maxRate;
        uint256 decayFactor;
        uint256 lastUpdate;
        bool isActive;
    }

    EmissionConfig public emissionConfig;
    mapping(uint256 => uint256) public cabinetEmissionMultiplier;

    // Events
    event TokensBurnedForOdds(address indexed user, uint256 amount, uint256 totalBurned);
    event CabinetRegistered(uint256 indexed cabinetId, address indexed owner, address indexed registrar);
    event CabinetRewardMinted(address indexed player, uint256 amount, uint256 indexed cabinetId);
    event CabinetPlayBurn(address indexed player, uint256 amount, uint256 indexed cabinetId);
    event CabinetStatusUpdated(uint256 indexed cabinetId, bool isActive);
    event EmissionRateUpdated(uint256 baseRate, uint256 maxRate, uint256 decayFactor);
    event EmissionConfigStatusUpdated(bool isActive);
    event CabinetEmissionMultiplierUpdated(uint256 indexed cabinetId, uint256 multiplier);

    constructor(
        address _accessControl,
        address _initialAdmin
    ) {
        require(_accessControl != address(0), "TuuCoinGaming: invalid access control address");
        require(_initialAdmin != address(0), "TuuCoinGaming: invalid admin address");

        accessControl = TuuKeepAccessControl(_accessControl);

        // Grant roles to initial admin
        _grantRole(DEFAULT_ADMIN_ROLE, _initialAdmin);
        _grantRole(PLATFORM_ADMIN_ROLE, _initialAdmin);
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
    }

    /**
     * @dev Set the TuuCoinBase contract address
     */
    function setTuuCoinBaseContract(address _tuuCoinBaseContract)
        external
        onlyRole(PLATFORM_ADMIN_ROLE)
    {
        require(_tuuCoinBaseContract != address(0), "TuuCoinGaming: invalid base contract address");
        tuuCoinBaseContract = _tuuCoinBaseContract;
    }

    // ============ CABINET INTEGRATION FUNCTIONS ============

    /**
     * @dev Register a new cabinet for token integration
     */
    function registerCabinet(uint256 cabinetId, address owner)
        external
        onlyRole(CABINET_OPERATOR_ROLE)
    {
        require(owner != address(0), "TuuCoinGaming: invalid owner address");
        require(!cabinetExists[cabinetId], "TuuCoinGaming: cabinet already registered");

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
     */
    function mintForGachaReward(address player, uint256 amount, uint256 cabinetId)
        external
        onlyRole(CABINET_OPERATOR_ROLE)
        whenNotPaused
    {
        require(player != address(0), "TuuCoinGaming: invalid player address");
        require(amount > 0, "TuuCoinGaming: amount must be greater than zero");
        require(cabinetExists[cabinetId], "TuuCoinGaming: cabinet not registered");
        require(cabinets[cabinetId].isActive, "TuuCoinGaming: cabinet not active");

        // Calculate emission-adjusted amount
        uint256 finalAmount = calculateEmissionAmount(cabinetId, amount);

        // Call base contract to mint
        (bool success, ) = tuuCoinBaseContract.call(
            abi.encodeWithSignature("mint(address,uint256)", player, finalAmount)
        );
        require(success, "TuuCoinGaming: minting failed");

        cabinets[cabinetId].totalEmitted += finalAmount;

        emit CabinetRewardMinted(player, finalAmount, cabinetId);
    }

    /**
     * @dev Burn tokens for gacha play with cabinet tracking
     */
    function burnForGachaPlay(address player, uint256 amount, uint256 cabinetId)
        external
        onlyRole(CABINET_OPERATOR_ROLE)
        whenNotPaused
    {
        require(player != address(0), "TuuCoinGaming: invalid player address");
        require(amount > 0, "TuuCoinGaming: amount must be greater than zero");
        require(cabinetExists[cabinetId], "TuuCoinGaming: cabinet not registered");
        require(cabinets[cabinetId].isActive, "TuuCoinGaming: cabinet not active");

        // Call base contract to burn from player
        (bool success, ) = tuuCoinBaseContract.call(
            abi.encodeWithSignature("burnFrom(address,uint256)", player, amount)
        );
        require(success, "TuuCoinGaming: burning failed");

        // Update burn tracking
        userBurnedAmount[player] += amount;
        userBurnCount[player] += 1;
        totalGamingBurned += amount;
        cabinets[cabinetId].totalBurned += amount;

        emit CabinetPlayBurn(player, amount, cabinetId);
        emit TokensBurnedForOdds(player, amount, userBurnedAmount[player]);
    }

    /**
     * @dev Update cabinet status (active/inactive)
     */
    function updateCabinetStatus(uint256 cabinetId, bool isActive)
        external
        onlyRole(CABINET_OPERATOR_ROLE)
    {
        require(cabinetExists[cabinetId], "TuuCoinGaming: cabinet not registered");

        cabinets[cabinetId].isActive = isActive;

        emit CabinetStatusUpdated(cabinetId, isActive);
    }

    // ============ EMISSION RATE CONTROL FUNCTIONS ============

    /**
     * @dev Update emission configuration
     */
    function updateEmissionConfig(
        uint256 newBaseRate,
        uint256 newMaxRate,
        uint256 newDecayFactor
    ) external onlyRole(EMISSION_MANAGER_ROLE) {
        require(newBaseRate > 0, "TuuCoinGaming: base rate must be positive");
        require(newMaxRate >= newBaseRate, "TuuCoinGaming: max rate must be >= base rate");
        require(newDecayFactor <= 10000, "TuuCoinGaming: decay factor must be <= 100%");

        emissionConfig.baseRate = newBaseRate;
        emissionConfig.maxRate = newMaxRate;
        emissionConfig.decayFactor = newDecayFactor;
        emissionConfig.lastUpdate = block.timestamp;

        emit EmissionRateUpdated(newBaseRate, newMaxRate, newDecayFactor);
    }

    /**
     * @dev Set emission multiplier for a specific cabinet
     */
    function setCabinetEmissionMultiplier(uint256 cabinetId, uint256 multiplier)
        external
        onlyRole(EMISSION_MANAGER_ROLE)
    {
        require(cabinetExists[cabinetId], "TuuCoinGaming: cabinet not registered");
        require(multiplier <= 50000, "TuuCoinGaming: multiplier too high (max 500%)");

        cabinetEmissionMultiplier[cabinetId] = multiplier;

        emit CabinetEmissionMultiplierUpdated(cabinetId, multiplier);
    }

    /**
     * @dev Toggle emission system active status
     */
    function setEmissionActive(bool isActive) external onlyRole(EMISSION_MANAGER_ROLE) {
        emissionConfig.isActive = isActive;
        emissionConfig.lastUpdate = block.timestamp;

        emit EmissionConfigStatusUpdated(isActive);
    }

    /**
     * @dev Calculate emission-adjusted amount for a cabinet
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

    // ============ ODDS IMPROVEMENT FUNCTIONS ============

    /**
     * @dev Burn tokens for odds improvement (direct burn by user)
     */
    function burnForOdds(address user, uint256 amount) external whenNotPaused {
        require(user != address(0), "TuuCoinGaming: invalid user address");
        require(amount > 0, "TuuCoinGaming: amount must be greater than zero");

        // Call base contract to burn from user
        (bool success, ) = tuuCoinBaseContract.call(
            abi.encodeWithSignature("burnFrom(address,uint256)", user, amount)
        );
        require(success, "TuuCoinGaming: burning failed");

        // Update burn tracking
        userBurnedAmount[user] += amount;
        userBurnCount[user] += 1;
        totalGamingBurned += amount;

        emit TokensBurnedForOdds(user, amount, userBurnedAmount[user]);
    }

    /**
     * @dev Get user's burn statistics for odds calculation
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

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Get current emission configuration
     */
    function getEmissionConfig() external view returns (EmissionConfig memory) {
        return emissionConfig;
    }

    /**
     * @dev Get cabinet emission multiplier
     */
    function getCabinetEmissionMultiplier(uint256 cabinetId) external view returns (uint256) {
        return cabinetEmissionMultiplier[cabinetId];
    }

    /**
     * @dev Get cabinet information
     */
    function getCabinetInfo(uint256 cabinetId) external view returns (CabinetIntegration memory) {
        require(cabinetExists[cabinetId], "TuuCoinGaming: cabinet not registered");
        return cabinets[cabinetId];
    }

    /**
     * @dev Check if cabinet is registered
     */
    function isCabinetRegistered(uint256 cabinetId) external view returns (bool) {
        return cabinetExists[cabinetId];
    }

    /**
     * @dev Get total number of registered cabinets
     */
    function getTotalCabinets() external view returns (uint256) {
        return totalCabinets;
    }

    /**
     * @dev Get cabinet statistics
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
        require(cabinetExists[cabinetId], "TuuCoinGaming: cabinet not registered");
        CabinetIntegration memory cabinet = cabinets[cabinetId];

        return (
            cabinet.totalEmitted,
            cabinet.totalBurned,
            cabinet.isActive,
            cabinet.owner
        );
    }

    // ============ ADMINISTRATIVE FUNCTIONS ============

    /**
     * @dev Emergency pause all contract operations
     */
    function pause() external onlyRole(EMERGENCY_RESPONDER_ROLE) {
        _pause();
    }

    /**
     * @dev Resume all contract operations
     */
    function unpause() external onlyRole(EMERGENCY_RESPONDER_ROLE) {
        _unpause();
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
}