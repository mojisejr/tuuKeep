// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title TuuKeepAccessControl
 * @dev Extended AccessControl utilities for TuuKeep platform with role-based permissions
 *
 * Features:
 * - Platform-specific role definitions for cabinet and marketplace operations
 * - Time-based role expiry system for enhanced security
 * - Activity tracking for security monitoring
 * - Batch role management operations for efficiency
 * - Integration with existing Randomness.sol patterns
 *
 * Platform Roles:
 * - PLATFORM_ADMIN_ROLE: System administration and emergency functions
 * - CABINET_MANAGER_ROLE: Cabinet creation and configuration management
 * - MARKETPLACE_OPERATOR_ROLE: Marketplace operations and fee management
 * - RANDOMNESS_CONSUMER_ROLE: Access to randomness utility functions
 */
contract TuuKeepAccessControl is AccessControl {

    // Platform-specific role definitions
    bytes32 public constant PLATFORM_ADMIN_ROLE = keccak256("PLATFORM_ADMIN_ROLE");
    bytes32 public constant CABINET_MANAGER_ROLE = keccak256("CABINET_MANAGER_ROLE");
    bytes32 public constant MARKETPLACE_OPERATOR_ROLE = keccak256("MARKETPLACE_OPERATOR_ROLE");
    bytes32 public constant RANDOMNESS_CONSUMER_ROLE = keccak256("RANDOMNESS_CONSUMER_ROLE");

    // Role expiry tracking
    struct RoleExpiry {
        uint256 expiryTime;
        bool isActive;
    }

    mapping(bytes32 => mapping(address => RoleExpiry)) private _roleExpiries;
    mapping(address => uint256) private _lastActivity;

    /// @dev Emitted when a role is granted with expiry time
    event RoleGrantedWithExpiry(
        bytes32 indexed role,
        address indexed account,
        uint256 expiryTime,
        address indexed admin
    );

    /// @dev Emitted when expired roles are revoked
    event ExpiredRolesRevoked(
        bytes32 indexed role,
        address indexed account,
        uint256 timestamp
    );

    /// @dev Emitted when user activity is tracked
    event ActivityTracked(
        address indexed account,
        bytes32 indexed role,
        uint256 timestamp
    );

    /**
     * @dev Constructor sets up default admin role
     * The deployer receives DEFAULT_ADMIN_ROLE and PLATFORM_ADMIN_ROLE
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PLATFORM_ADMIN_ROLE, msg.sender);

        // Set up role hierarchy
        _setRoleAdmin(CABINET_MANAGER_ROLE, PLATFORM_ADMIN_ROLE);
        _setRoleAdmin(MARKETPLACE_OPERATOR_ROLE, PLATFORM_ADMIN_ROLE);
        _setRoleAdmin(RANDOMNESS_CONSUMER_ROLE, PLATFORM_ADMIN_ROLE);
    }

    /**
     * @dev Grant role with expiry time for enhanced security
     * @param role The role identifier to grant
     * @param account The address to grant the role to
     * @param duration The duration in seconds for which the role is valid
     */
    function grantRoleWithExpiry(
        bytes32 role,
        address account,
        uint256 duration
    ) external onlyRole(getRoleAdmin(role)) {
        require(duration > 0, "TuuKeepAccessControl: duration must be positive");
        require(account != address(0), "TuuKeepAccessControl: invalid account");

        uint256 expiryTime = block.timestamp + duration;

        // Grant the role using OpenZeppelin's function
        _grantRole(role, account);

        // Set expiry information
        _roleExpiries[role][account] = RoleExpiry({
            expiryTime: expiryTime,
            isActive: true
        });

        emit RoleGrantedWithExpiry(role, account, expiryTime, msg.sender);
    }

    /**
     * @dev Check if an account has an active (non-expired) role
     * @param role The role identifier to check
     * @param account The address to check
     * @return bool True if the account has an active role
     */
    function hasActiveRole(bytes32 role, address account) external view returns (bool) {
        // First check if role is granted
        if (!hasRole(role, account)) {
            return false;
        }

        // Check if role has expiry set
        RoleExpiry memory roleExpiry = _roleExpiries[role][account];
        if (!roleExpiry.isActive) {
            return true; // No expiry set, role is permanently active
        }

        // Check if role has expired
        return block.timestamp <= roleExpiry.expiryTime;
    }

    /**
     * @dev Revoke expired roles for a specific account and role
     * Can be called by anyone to maintain system hygiene
     * @param role The role identifier to check
     * @param account The address to check
     */
    function revokeExpiredRole(bytes32 role, address account) external {
        require(hasRole(role, account), "TuuKeepAccessControl: account does not have role");

        RoleExpiry memory roleExpiry = _roleExpiries[role][account];
        require(roleExpiry.isActive, "TuuKeepAccessControl: role has no expiry");
        require(block.timestamp > roleExpiry.expiryTime, "TuuKeepAccessControl: role not expired");

        // Revoke the role
        _revokeRole(role, account);

        // Clear expiry data
        delete _roleExpiries[role][account];

        emit ExpiredRolesRevoked(role, account, block.timestamp);
    }

    /**
     * @dev Batch revoke expired roles for multiple accounts
     * Gas-efficient cleanup function
     * @param roles Array of role identifiers
     * @param accounts Array of addresses (must match roles length)
     */
    function batchRevokeExpiredRoles(
        bytes32[] calldata roles,
        address[] calldata accounts
    ) external {
        require(roles.length == accounts.length, "TuuKeepAccessControl: arrays length mismatch");

        for (uint256 i = 0; i < roles.length; i++) {
            bytes32 role = roles[i];
            address account = accounts[i];

            if (hasRole(role, account)) {
                RoleExpiry memory roleExpiry = _roleExpiries[role][account];
                if (roleExpiry.isActive && block.timestamp > roleExpiry.expiryTime) {
                    _revokeRole(role, account);
                    delete _roleExpiries[role][account];
                    emit ExpiredRolesRevoked(role, account, block.timestamp);
                }
            }
        }
    }

    /**
     * @dev Track user activity for security monitoring
     * Should be called by contracts when users perform significant actions
     * @param account The address performing the action
     * @param role The role associated with the action
     */
    function trackActivity(address account, bytes32 role) external {
        require(hasRole(role, account), "TuuKeepAccessControl: account lacks active role");

        _lastActivity[account] = block.timestamp;
        emit ActivityTracked(account, role, block.timestamp);
    }

    /**
     * @dev Get the last activity timestamp for an account
     * @param account The address to check
     * @return uint256 The timestamp of last activity
     */
    function getLastActivity(address account) external view returns (uint256) {
        return _lastActivity[account];
    }

    /**
     * @dev Get role expiry information
     * @param role The role identifier
     * @param account The address to check
     * @return expiryTime The timestamp when the role expires (0 if no expiry)
     * @return isActive Whether the role has expiry enabled
     */
    function getRoleExpiry(bytes32 role, address account)
        external
        view
        returns (uint256 expiryTime, bool isActive)
    {
        RoleExpiry memory roleExpiry = _roleExpiries[role][account];
        return (roleExpiry.expiryTime, roleExpiry.isActive);
    }

    /**
     * @dev Override hasRole to include expiry check
     * @param role The role identifier
     * @param account The address to check
     * @return bool True if the account has an active, non-expired role
     */
    function hasRole(bytes32 role, address account)
        public
        view
        virtual
        override
        returns (bool)
    {
        // First check if role is granted in the base contract
        bool hasBaseRole = super.hasRole(role, account);
        if (!hasBaseRole) {
            return false;
        }

        // Check expiry if applicable
        RoleExpiry memory roleExpiry = _roleExpiries[role][account];
        if (!roleExpiry.isActive) {
            return true; // No expiry set, role is active
        }

        return block.timestamp <= roleExpiry.expiryTime;
    }

    /**
     * @dev Emergency function to extend role expiry
     * Can only be called by role admin
     * @param role The role identifier
     * @param account The address to extend
     * @param additionalTime Additional seconds to add to expiry
     */
    function extendRoleExpiry(
        bytes32 role,
        address account,
        uint256 additionalTime
    ) external onlyRole(getRoleAdmin(role)) {
        require(super.hasRole(role, account), "TuuKeepAccessControl: account does not have role");
        require(additionalTime > 0, "TuuKeepAccessControl: additional time must be positive");

        RoleExpiry storage roleExpiry = _roleExpiries[role][account];
        require(roleExpiry.isActive, "TuuKeepAccessControl: role has no expiry");

        roleExpiry.expiryTime += additionalTime;

        emit RoleGrantedWithExpiry(role, account, roleExpiry.expiryTime, msg.sender);
    }
}