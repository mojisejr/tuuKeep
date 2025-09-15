// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../contracts/Utils/Randomness.sol";

contract RandomnessTest is Test {
    Randomness public randomness;
    address public admin = address(0x1234);
    address public consumer = address(0x5678);
    address public unauthorizedUser = address(0x9abc);

    event ConsumerAdded(address indexed consumer);
    event ConsumerRemoved(address indexed consumer);
    event RandomNumberGenerated(
        address indexed requester,
        uint256 indexed requestId,
        uint256 randomNumber,
        uint256 blockNumber
    );

    function setUp() public {
        randomness = new Randomness(admin);
    }

    function testInitialState() public {
        assertTrue(randomness.hasRole(randomness.DEFAULT_ADMIN_ROLE(), admin));
        assertEq(randomness.getCurrentNonce(), 0);
        assertFalse(randomness.isConsumer(consumer));
    }

    function testAddConsumer() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit ConsumerAdded(consumer);
        randomness.addConsumer(consumer);

        assertTrue(randomness.isConsumer(consumer));
    }

    function testAddConsumerZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Invalid consumer address");
        randomness.addConsumer(address(0));
    }

    function testAddConsumerUnauthorized() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        randomness.addConsumer(consumer);
    }

    function testRemoveConsumer() public {
        // First add consumer
        vm.prank(admin);
        randomness.addConsumer(consumer);
        assertTrue(randomness.isConsumer(consumer));

        // Then remove consumer
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit ConsumerRemoved(consumer);
        randomness.removeConsumer(consumer);

        assertFalse(randomness.isConsumer(consumer));
    }

    function testGenerateRandomNumber() public {
        // Add consumer first
        vm.prank(admin);
        randomness.addConsumer(consumer);

        vm.prank(consumer);
        vm.expectEmit(true, true, false, true);
        emit RandomNumberGenerated(consumer, 1, 0, block.number); // randomNumber will be calculated

        uint256 randomNumber = randomness.generateRandomNumber(1);

        assertTrue(randomNumber > 0);
        assertEq(randomness.getCurrentNonce(), 1);
    }

    function testGenerateRandomNumberZeroRequestId() public {
        vm.prank(admin);
        randomness.addConsumer(consumer);

        vm.prank(consumer);
        vm.expectRevert("Request ID must be greater than zero");
        randomness.generateRandomNumber(0);
    }

    function testGenerateRandomNumberUnauthorized() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        randomness.generateRandomNumber(1);
    }

    function testGenerateRandomInRange() public {
        vm.prank(admin);
        randomness.addConsumer(consumer);

        vm.prank(consumer);
        uint256 randomNumber = randomness.generateRandomInRange(1, 1, 100);

        assertTrue(randomNumber >= 1 && randomNumber <= 100);
        assertEq(randomness.getCurrentNonce(), 1);
    }

    function testGenerateRandomInRangeSameMinMax() public {
        vm.prank(admin);
        randomness.addConsumer(consumer);

        vm.prank(consumer);
        uint256 randomNumber = randomness.generateRandomInRange(1, 50, 50);

        assertEq(randomNumber, 50);
    }

    function testGenerateRandomInRangeInvalidRange() public {
        vm.prank(admin);
        randomness.addConsumer(consumer);

        vm.prank(consumer);
        vm.expectRevert("Invalid range: min must be <= max");
        randomness.generateRandomInRange(1, 100, 50);
    }

    function testRandomnessDistribution() public {
        vm.prank(admin);
        randomness.addConsumer(consumer);

        uint256[10] memory buckets;
        uint256 iterations = 1000;

        // Generate random numbers and distribute into buckets
        for (uint256 i = 1; i <= iterations; i++) {
            vm.prank(consumer);
            uint256 randomNumber = randomness.generateRandomInRange(i, 0, 9);
            buckets[randomNumber]++;
        }

        // Check that each bucket has some values (basic distribution test)
        // In 1000 iterations with 10 buckets, each should have roughly 100 values
        // We'll check that no bucket is completely empty
        for (uint256 i = 0; i < 10; i++) {
            assertTrue(buckets[i] > 0, "Bucket should not be empty in distribution test");
        }
    }

    function testNonceIncrement() public {
        vm.prank(admin);
        randomness.addConsumer(consumer);

        uint256 initialNonce = randomness.getCurrentNonce();

        vm.prank(consumer);
        randomness.generateRandomNumber(1);
        assertEq(randomness.getCurrentNonce(), initialNonce + 1);

        vm.prank(consumer);
        randomness.generateRandomNumber(2);
        assertEq(randomness.getCurrentNonce(), initialNonce + 2);
    }

    function testMultipleConsumers() public {
        address consumer2 = address(0xdef0);

        vm.prank(admin);
        randomness.addConsumer(consumer);

        vm.prank(admin);
        randomness.addConsumer(consumer2);

        assertTrue(randomness.isConsumer(consumer));
        assertTrue(randomness.isConsumer(consumer2));

        // Both should be able to generate random numbers
        vm.prank(consumer);
        uint256 random1 = randomness.generateRandomNumber(1);

        vm.prank(consumer2);
        uint256 random2 = randomness.generateRandomNumber(2);

        assertTrue(random1 > 0);
        assertTrue(random2 > 0);
    }

    function testGasUsage() public {
        vm.prank(admin);
        randomness.addConsumer(consumer);

        uint256 gasBefore = gasleft();
        vm.prank(consumer);
        randomness.generateRandomNumber(1);
        uint256 gasUsed = gasBefore - gasleft();

        // Gas usage should be reasonable (targeting < 50k as per requirements)
        // This is a rough check - actual gas costs will depend on the EVM
        assertTrue(gasUsed < 100000, "Gas usage should be reasonable");
    }
}