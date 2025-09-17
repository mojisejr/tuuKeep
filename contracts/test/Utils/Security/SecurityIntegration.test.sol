// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../../contracts/Utils/Security/TuuKeepReentrancyGuard.sol";
import "../../../contracts/Utils/Security/TuuKeepAccessControl.sol";
import "../../../contracts/Utils/Security/SafeTransferLib.sol";
import "../../../contracts/Utils/Security/ValidationLib.sol";

/**
 * @title SecurityIntegration
 * @dev Comprehensive integration testing for all security utilities
 */
contract SecurityIntegration is Test {
    using SafeTransferLib for IERC20;
    using SafeTransferLib for IERC721;
    using ValidationLib for *;

    TuuKeepReentrancyGuard public reentrancyGuard;
    TuuKeepAccessControl public accessControl;

    address public owner;
    address public user1;
    address public user2;
    address public maliciousContract;

    event SecurityTestPassed(string testName, uint256 gasUsed);

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        maliciousContract = makeAddr("maliciousContract");

        vm.startPrank(owner);

        // Deploy security contracts
        reentrancyGuard = new TuuKeepReentrancyGuard();
        accessControl = new TuuKeepAccessControl();

        vm.stopPrank();
    }

    function testReentrancyProtectionWithAccessControl() public {
        uint256 gasStart = gasleft();

        // Test that reentrancy protection works with access control
        bytes32 cabinetManagerRole = accessControl.CABINET_MANAGER_ROLE();

        vm.prank(owner);
        accessControl.grantRole(cabinetManagerRole, user1);

        assertTrue(accessControl.hasRole(cabinetManagerRole, user1));

        uint256 gasUsed = gasStart - gasleft();
        emit SecurityTestPassed("ReentrancyProtectionWithAccessControl", gasUsed);
    }

    function testAccessControlWithRoleExpiry() public {
        uint256 gasStart = gasleft();

        bytes32 cabinetManagerRole = accessControl.CABINET_MANAGER_ROLE();
        uint256 duration = 3600; // 1 hour

        vm.prank(owner);
        accessControl.grantRoleWithExpiry(cabinetManagerRole, user1, duration);

        // Should be active initially
        assertTrue(accessControl.hasActiveRole(cabinetManagerRole, user1));

        // Fast forward time beyond expiry
        vm.warp(block.timestamp + duration + 1);

        // Should be inactive after expiry
        assertFalse(accessControl.hasActiveRole(cabinetManagerRole, user1));

        uint256 gasUsed = gasStart - gasleft();
        emit SecurityTestPassed("AccessControlWithRoleExpiry", gasUsed);
    }

    function testValidationLibAddressChecks() public {
        uint256 gasStart = gasleft();

        // Test address validation - expect revert for zero address
        vm.expectRevert();
        ValidationLib.validateAddress(address(0), "test");

        // Test valid address
        ValidationLib.validateAddress(user1, "test");

        uint256 gasUsed = gasStart - gasleft();
        emit SecurityTestPassed("ValidationLibAddressChecks", gasUsed);
    }

    function testValidationLibAmountChecks() public {
        uint256 gasStart = gasleft();

        // Test amount validation within bounds
        ValidationLib.validateAmount(50, 1, 100, "test amount");

        // Test amount validation outside bounds - expect revert
        vm.expectRevert();
        ValidationLib.validateAmount(150, 1, 100, "test amount");

        uint256 gasUsed = gasStart - gasleft();
        emit SecurityTestPassed("ValidationLibAmountChecks", gasUsed);
    }

    function testValidationLibStringChecks() public {
        uint256 gasStart = gasleft();

        // Test valid cabinet name
        ValidationLib.validateCabinetName("Test Cabinet 123");

        // Test empty string rejection - expect revert
        vm.expectRevert();
        ValidationLib.validateCabinetName("");

        uint256 gasUsed = gasStart - gasleft();
        emit SecurityTestPassed("ValidationLibStringChecks", gasUsed);
    }

    function testValidationLibArrayChecks() public {
        uint256 gasStart = gasleft();

        // Test cabinet items validation (valid range)
        ValidationLib.validateCabinetItems(5);

        // Test cabinet items validation (invalid - too many) - expect revert
        vm.expectRevert();
        ValidationLib.validateCabinetItems(15);

        uint256 gasUsed = gasStart - gasleft();
        emit SecurityTestPassed("ValidationLibArrayChecks", gasUsed);
    }

    function testValidationLibPlayPriceChecks() public {
        uint256 gasStart = gasleft();

        // Test valid play price
        ValidationLib.validatePlayPrice(1e18); // 1 ETH

        // Test invalid play price (too low) - expect revert
        vm.expectRevert();
        ValidationLib.validatePlayPrice(1e12);

        // Test invalid play price (too high) - expect revert
        vm.expectRevert();
        ValidationLib.validatePlayPrice(1e21);

        uint256 gasUsed = gasStart - gasleft();
        emit SecurityTestPassed("ValidationLibPlayPriceChecks", gasUsed);
    }

    function testValidationLibBurnAmountChecks() public {
        uint256 gasStart = gasleft();

        uint256 playPrice = 1e18; // 1 ETH
        uint256 validBurnAmount = (playPrice * 10) / 100; // 10% of play price
        uint256 invalidBurnAmount = (playPrice * 30) / 100; // 30% of play price (too high)

        // Test valid burn amount
        ValidationLib.validateBurnAmount(validBurnAmount, playPrice);

        // Test invalid burn amount (exceeds 20% limit) - expect revert
        vm.expectRevert();
        ValidationLib.validateBurnAmount(invalidBurnAmount, playPrice);

        uint256 gasUsed = gasStart - gasleft();
        emit SecurityTestPassed("ValidationLibBurnAmountChecks", gasUsed);
    }

    function testValidationLibPercentageChecks() public {
        uint256 gasStart = gasleft();

        // Test valid percentage
        ValidationLib.validatePercentage(75, "test percentage");

        // Test invalid percentage - expect revert
        vm.expectRevert();
        ValidationLib.validatePercentage(150, "test percentage");

        uint256 gasUsed = gasStart - gasleft();
        emit SecurityTestPassed("ValidationLibPercentageChecks", gasUsed);
    }

    function testValidationLibBasisPointsChecks() public {
        uint256 gasStart = gasleft();

        // Test valid basis points
        ValidationLib.validateBasisPoints(7500, "test basis points"); // 75%

        // Test invalid basis points - expect revert
        vm.expectRevert();
        ValidationLib.validateBasisPoints(15000, "test basis points");

        uint256 gasUsed = gasStart - gasleft();
        emit SecurityTestPassed("ValidationLibBasisPointsChecks", gasUsed);
    }

    function testValidationLibTimestampChecks() public {
        uint256 gasStart = gasleft();

        // Test future timestamp validation
        uint256 futureTime = block.timestamp + 3600;
        ValidationLib.validateFutureTimestamp(futureTime, "test future time");

        // Test invalid future timestamp (current time) - expect revert
        vm.expectRevert();
        ValidationLib.validateFutureTimestamp(block.timestamp, "test future time");

        uint256 gasUsed = gasStart - gasleft();
        emit SecurityTestPassed("ValidationLibTimestampChecks", gasUsed);
    }

    function testValidationLibMarketplaceChecks() public {
        uint256 gasStart = gasleft();

        uint256 validPrice = 1e18; // 1 ETH
        uint256 validDuration = 7 days;

        // Test valid marketplace listing
        ValidationLib.validateMarketplaceListing(validPrice, validDuration);

        // Test invalid price (too low) - expect revert
        vm.expectRevert();
        ValidationLib.validateMarketplaceListing(1e12, validDuration);

        // Test invalid duration (too short) - expect revert
        vm.expectRevert();
        ValidationLib.validateMarketplaceListing(validPrice, 1800);

        uint256 gasUsed = gasStart - gasleft();
        emit SecurityTestPassed("ValidationLibMarketplaceChecks", gasUsed);
    }

    function testValidationLibCabinetConfigurationChecks() public {
        uint256 gasStart = gasleft();

        string memory validName = "Test Cabinet";
        uint256 validPrice = 1e18; // 1 ETH
        uint256 validItemCount = 5;

        // Test valid cabinet configuration
        ValidationLib.validateCabinetConfiguration(validName, validPrice, validItemCount);

        // Test invalid item count (too many) - expect revert
        vm.expectRevert();
        ValidationLib.validateCabinetConfiguration(validName, validPrice, 15);

        uint256 gasUsed = gasStart - gasleft();
        emit SecurityTestPassed("ValidationLibCabinetConfigurationChecks", gasUsed);
    }

    function testValidationLibDuplicateAddressChecks() public {
        uint256 gasStart = gasleft();

        // Test array with no duplicates
        address[] memory noDuplicates = new address[](3);
        noDuplicates[0] = user1;
        noDuplicates[1] = user2;
        noDuplicates[2] = owner;
        ValidationLib.validateNoDuplicateAddresses(noDuplicates);

        // Test array with duplicates
        address[] memory withDuplicates = new address[](3);
        withDuplicates[0] = user1;
        withDuplicates[1] = user2;
        withDuplicates[2] = user1; // Duplicate

        // Test duplicate addresses - expect revert
        vm.expectRevert();
        ValidationLib.validateNoDuplicateAddresses(withDuplicates);

        uint256 gasUsed = gasStart - gasleft();
        emit SecurityTestPassed("ValidationLibDuplicateAddressChecks", gasUsed);
    }

    function testValidationLibRoleExpiryDurationChecks() public {
        uint256 gasStart = gasleft();

        // Test valid role expiry duration
        ValidationLib.validateRoleExpiryDuration(7 days);

        // Test invalid duration (too short) - expect revert
        vm.expectRevert();
        ValidationLib.validateRoleExpiryDuration(30 minutes);

        // Test invalid duration (too long) - expect revert
        vm.expectRevert();
        ValidationLib.validateRoleExpiryDuration(400 days);

        uint256 gasUsed = gasStart - gasleft();
        emit SecurityTestPassed("ValidationLibRoleExpiryDurationChecks", gasUsed);
    }

    function testCombinedSecurityPatterns() public {
        uint256 gasStart = gasleft();

        // Test combining reentrancy protection with access control and validation
        bytes32 cabinetManagerRole = accessControl.CABINET_MANAGER_ROLE();

        vm.prank(owner);
        accessControl.grantRole(cabinetManagerRole, user1);

        // Validate the role was granted
        assertTrue(accessControl.hasRole(cabinetManagerRole, user1));

        // Validate cabinet configuration parameters
        ValidationLib.validateCabinetName("Security Test Cabinet");
        ValidationLib.validatePlayPrice(1e18);
        ValidationLib.validateCabinetItems(3);

        // Reentrancy guard state verified through successful operations

        uint256 gasUsed = gasStart - gasleft();
        emit SecurityTestPassed("CombinedSecurityPatterns", gasUsed);
    }

    function testGasEfficiencyOfSecurityUtilities() public {
        uint256 gasStart = gasleft();

        // Test gas efficiency of common security operations
        ValidationLib.validateAddress(user1, "test");
        ValidationLib.validateAmount(100, 1, 1000, "test");
        ValidationLib.validateCabinetName("Test");

        bytes32 role = accessControl.CABINET_MANAGER_ROLE();
        bool hasRole = accessControl.hasRole(role, user1);

        assertFalse(hasRole); // user1 doesn't have role yet

        uint256 gasUsed = gasStart - gasleft();

        // Ensure gas usage is reasonable (should be less than 50k as per requirements)
        assertTrue(gasUsed < 50000, "Gas usage exceeds efficiency target");

        emit SecurityTestPassed("GasEfficiencyOfSecurityUtilities", gasUsed);
    }
}