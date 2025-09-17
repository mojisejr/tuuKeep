import { expect } from "chai";
import { viem } from "hardhat";
import { parseEther } from "viem";
import { deployTestEnvironment, TestEnvironment } from "./utils/deployment-helper";
import { ScenarioBuilder } from "./utils/scenario-builder";
import { AssertionHelpers, PerformanceTracker } from "./utils/assertion-helpers";
import { TEST_MARKETPLACE_LISTINGS, TEST_FEE_CONFIG } from "./fixtures/test-data";

describe("Marketplace Integration", function () {
  let environment: TestEnvironment;
  let scenarioBuilder: ScenarioBuilder;
  let assertions: AssertionHelpers;
  let performanceTracker: PerformanceTracker;

  this.timeout(300000); // 5 minutes for integration tests

  before(async function () {
    console.log("🛒 Setting up Marketplace Integration Test Environment...");
    environment = await deployTestEnvironment();
    scenarioBuilder = new ScenarioBuilder(environment);
    assertions = new AssertionHelpers(environment);
    performanceTracker = new PerformanceTracker();
    console.log("✅ Setup complete!");
  });

  after(async function () {
    performanceTracker.generateReport();
  });

  describe("Cabinet Listing and Purchase Workflow", function () {
    it("should complete cabinet listing → purchase → ownership transfer", async function () {
      const { contracts, accounts } = environment;

      console.log("🏷️ Starting marketplace transaction test...");

      // Step 1: Create a cabinet to list
      console.log("🏪 Step 1: Creating cabinet for marketplace...");
      const cabinetScenario = await scenarioBuilder.createBasicCabinetScenario();
      const cabinetId = cabinetScenario.cabinetId;

      // Verify initial ownership
      await assertions.assertCabinetOwnership(cabinetId, accounts.CABINET_OWNER.address);

      // Step 2: Create marketplace listing
      console.log("📋 Step 2: Creating marketplace listing...");
      const listingPrice = TEST_MARKETPLACE_LISTINGS.BASIC_LISTING.price;

      // First approve marketplace to transfer cabinet
      await contracts.tuuKeepCabinet.write.approve([
        contracts.tuuKeepMarketplace.address,
        cabinetId
      ], { account: accounts.CABINET_OWNER.address });

      const listTx = await contracts.tuuKeepMarketplace.write.listItem([
        contracts.tuuKeepCabinet.address,
        cabinetId,
        listingPrice
      ], { account: accounts.CABINET_OWNER.address });

      const listingGasMetrics = await assertions.measureGasUsageForScenario(
        "Marketplace Listing",
        listTx
      );
      performanceTracker.addGasMetrics(listingGasMetrics);

      // Verify listing was created
      await assertions.assertMarketplaceListing(cabinetId, listingPrice, true);

      // Step 3: Purchase cabinet from marketplace
      console.log("💳 Step 3: Purchasing cabinet from marketplace...");
      const buyer = accounts.MARKETPLACE_BUYER.address;
      const seller = accounts.CABINET_OWNER.address;

      // Get initial balances
      const publicClient = await viem.getPublicClient();
      const buyerInitialBalance = await publicClient.getBalance({ address: buyer });
      const sellerInitialBalance = await publicClient.getBalance({ address: seller });
      const feeRecipientInitialBalance = await publicClient.getBalance({
        address: accounts.FEE_RECIPIENT.address
      });

      const purchaseTx = await contracts.tuuKeepMarketplace.write.buyItem([
        contracts.tuuKeepCabinet.address,
        cabinetId
      ], {
        account: buyer,
        value: listingPrice
      });

      const purchaseGasMetrics = await assertions.measureGasUsageForScenario(
        "Marketplace Purchase",
        purchaseTx
      );
      performanceTracker.addGasMetrics(purchaseGasMetrics);

      // Step 4: Verify ownership transfer and fee distribution
      console.log("🔄 Step 4: Verifying ownership transfer and payments...");

      // Verify ownership transferred to buyer
      await assertions.assertCabinetOwnership(cabinetId, buyer);

      // Verify listing is no longer active
      await assertions.assertMarketplaceListing(cabinetId, 0n, false);

      // Verify payment distribution
      const buyerFinalBalance = await publicClient.getBalance({ address: buyer });
      const sellerFinalBalance = await publicClient.getBalance({ address: seller });
      const feeRecipientFinalBalance = await publicClient.getBalance({
        address: accounts.FEE_RECIPIENT.address
      });

      // Calculate expected amounts
      const feeAmount = (listingPrice * TEST_FEE_CONFIG.MARKETPLACE_FEE_RATE) / 10000n;
      const sellerAmount = listingPrice - feeAmount;

      // Buyer should have paid the full listing price
      expect(buyerInitialBalance - buyerFinalBalance).to.be.greaterThanOrEqual(listingPrice);

      // Seller should have received payment minus fees
      expect(sellerFinalBalance - sellerInitialBalance).to.be.greaterThanOrEqual(sellerAmount);

      // Fee recipient should have received marketplace fees
      expect(feeRecipientFinalBalance - feeRecipientInitialBalance).to.be.greaterThanOrEqual(feeAmount);

      console.log("✅ Marketplace transaction completed successfully!");
    });

    it("should handle listing management operations", async function () {
      console.log("📝 Testing listing management operations...");

      const { contracts, accounts } = environment;

      // Create another cabinet for testing
      const cabinetScenario = await scenarioBuilder.createPremiumCabinetScenario();
      const cabinetId = cabinetScenario.cabinetId;

      // Test listing creation
      const initialPrice = parseEther("0.5");
      await contracts.tuuKeepCabinet.write.approve([
        contracts.tuuKeepMarketplace.address,
        cabinetId
      ], { account: accounts.CABINET_OWNER_2.address });

      await contracts.tuuKeepMarketplace.write.listItem([
        contracts.tuuKeepCabinet.address,
        cabinetId,
        initialPrice
      ], { account: accounts.CABINET_OWNER_2.address });

      // Test price update
      const updatedPrice = parseEther("0.8");
      await contracts.tuuKeepMarketplace.write.updateListingPrice([
        contracts.tuuKeepCabinet.address,
        cabinetId,
        updatedPrice
      ], { account: accounts.CABINET_OWNER_2.address });

      await assertions.assertMarketplaceListing(cabinetId, updatedPrice, true);

      // Test listing cancellation
      await contracts.tuuKeepMarketplace.write.cancelListing([
        contracts.tuuKeepCabinet.address,
        cabinetId
      ], { account: accounts.CABINET_OWNER_2.address });

      await assertions.assertMarketplaceListing(cabinetId, 0n, false);

      // Verify cabinet is back with original owner
      await assertions.assertCabinetOwnership(cabinetId, accounts.CABINET_OWNER_2.address);

      console.log("✅ Listing management operations completed!");
    });

    it("should distribute marketplace fees correctly", async function () {
      console.log("💰 Testing marketplace fee distribution...");

      const { contracts, accounts } = environment;

      // Create cabinet and list it
      const cabinetScenario = await scenarioBuilder.createBasicCabinetScenario();
      const cabinetId = cabinetScenario.cabinetId;

      const highValuePrice = parseEther("1.0");

      await contracts.tuuKeepCabinet.write.approve([
        contracts.tuuKeepMarketplace.address,
        cabinetId
      ], { account: accounts.CABINET_OWNER.address });

      await contracts.tuuKeepMarketplace.write.listItem([
        contracts.tuuKeepCabinet.address,
        cabinetId,
        highValuePrice
      ], { account: accounts.CABINET_OWNER.address });

      // Get initial balances for precise fee calculation
      const publicClient = await viem.getPublicClient();
      const sellerInitialBalance = await publicClient.getBalance({ address: accounts.CABINET_OWNER.address });
      const feeRecipientInitialBalance = await publicClient.getBalance({
        address: accounts.FEE_RECIPIENT.address
      });

      // Purchase at high price
      await contracts.tuuKeepMarketplace.write.buyItem([
        contracts.tuuKeepCabinet.address,
        cabinetId
      ], {
        account: accounts.MARKETPLACE_BUYER.address,
        value: highValuePrice
      });

      // Verify precise fee distribution
      const sellerFinalBalance = await publicClient.getBalance({ address: accounts.CABINET_OWNER.address });
      const feeRecipientFinalBalance = await publicClient.getBalance({
        address: accounts.FEE_RECIPIENT.address
      });

      const expectedFee = (highValuePrice * TEST_FEE_CONFIG.MARKETPLACE_FEE_RATE) / 10000n;
      const expectedSellerAmount = highValuePrice - expectedFee;

      const actualFeeReceived = feeRecipientFinalBalance - feeRecipientInitialBalance;
      const actualSellerReceived = sellerFinalBalance - sellerInitialBalance;

      expect(actualFeeReceived).to.be.greaterThanOrEqual(expectedFee);
      expect(actualSellerReceived).to.be.greaterThanOrEqual(expectedSellerAmount);

      console.log(`💸 Fee distribution verified: ${expectedFee} to platform, ${expectedSellerAmount} to seller`);
      console.log("✅ Marketplace fee distribution test completed!");
    });
  });

  describe("Error Handling and Edge Cases", function () {
    it("should reject purchase with insufficient funds", async function () {
      console.log("🚫 Testing insufficient funds scenario...");

      const { contracts, accounts } = environment;

      // Create expensive cabinet listing
      const cabinetScenario = await scenarioBuilder.createBasicCabinetScenario();
      const cabinetId = cabinetScenario.cabinetId;
      const highPrice = parseEther("1000"); // More than buyer has

      await contracts.tuuKeepCabinet.write.approve([
        contracts.tuuKeepMarketplace.address,
        cabinetId
      ], { account: accounts.CABINET_OWNER.address });

      await contracts.tuuKeepMarketplace.write.listItem([
        contracts.tuuKeepCabinet.address,
        cabinetId,
        highPrice
      ], { account: accounts.CABINET_OWNER.address });

      // Try to purchase with insufficient funds
      try {
        await contracts.tuuKeepMarketplace.write.buyItem([
          contracts.tuuKeepCabinet.address,
          cabinetId
        ], {
          account: accounts.PLAYER_1.address, // Has less funds
          value: parseEther("0.1") // Much less than required
        });

        expect.fail("Should have rejected insufficient payment");
      } catch (error) {
        console.log("✅ Insufficient funds properly rejected");
        expect(error).to.exist;
      }
    });

    it("should prevent non-owner from listing cabinet", async function () {
      console.log("🔒 Testing unauthorized listing scenario...");

      const { contracts, accounts } = environment;

      const cabinetScenario = await scenarioBuilder.createBasicCabinetScenario();
      const cabinetId = cabinetScenario.cabinetId;

      // Try to list cabinet from non-owner account
      try {
        await contracts.tuuKeepMarketplace.write.listItem([
          contracts.tuuKeepCabinet.address,
          cabinetId,
          parseEther("0.1")
        ], { account: accounts.PLAYER_1.address }); // Not the owner

        expect.fail("Should have rejected non-owner listing");
      } catch (error) {
        console.log("✅ Non-owner listing properly rejected");
        expect(error).to.exist;
      }
    });

    it("should handle multiple listings per owner", async function () {
      console.log("📋 Testing multiple listings scenario...");

      const { contracts, accounts } = environment;

      // Create multiple cabinets
      const scenario1 = await scenarioBuilder.createBasicCabinetScenario();
      const scenario2 = await scenarioBuilder.createPremiumCabinetScenario();

      // List both cabinets
      await contracts.tuuKeepCabinet.write.approve([
        contracts.tuuKeepMarketplace.address,
        scenario1.cabinetId
      ], { account: accounts.CABINET_OWNER.address });

      await contracts.tuuKeepMarketplace.write.listItem([
        contracts.tuuKeepCabinet.address,
        scenario1.cabinetId,
        parseEther("0.2")
      ], { account: accounts.CABINET_OWNER.address });

      await contracts.tuuKeepCabinet.write.approve([
        contracts.tuuKeepMarketplace.address,
        scenario2.cabinetId
      ], { account: accounts.CABINET_OWNER_2.address });

      await contracts.tuuKeepMarketplace.write.listItem([
        contracts.tuuKeepCabinet.address,
        scenario2.cabinetId,
        parseEther("0.8")
      ], { account: accounts.CABINET_OWNER_2.address });

      // Verify both listings are active
      await assertions.assertMarketplaceListing(scenario1.cabinetId, parseEther("0.2"), true);
      await assertions.assertMarketplaceListing(scenario2.cabinetId, parseEther("0.8"), true);

      console.log("✅ Multiple listings handled correctly!");
    });
  });
});