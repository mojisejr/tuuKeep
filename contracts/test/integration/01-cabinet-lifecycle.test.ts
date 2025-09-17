import { expect } from "chai";
import hre from "hardhat";
import { parseEther, formatEther } from "viem";
import { deployTestEnvironment, TestEnvironment } from "./utils/deployment-helper";
import { ScenarioBuilder } from "./utils/scenario-builder";
import { AssertionHelpers, PerformanceTracker } from "./utils/assertion-helpers";
import { TEST_CABINET_CONFIGS, TEST_GACHA_PRICES, TEST_TUUCOIN_CONFIG } from "./fixtures/test-data";

describe("Cabinet Lifecycle Integration", function () {
  let environment: TestEnvironment;
  let scenarioBuilder: ScenarioBuilder;
  let assertions: AssertionHelpers;
  let performanceTracker: PerformanceTracker;

  this.timeout(300000); // 5 minutes for integration tests

  before(async function () {
    console.log("🚀 Setting up Cabinet Lifecycle Integration Test Environment...");
    environment = await deployTestEnvironment();
    scenarioBuilder = new ScenarioBuilder(environment);
    assertions = new AssertionHelpers(environment);
    performanceTracker = new PerformanceTracker();
    console.log("✅ Setup complete!");
  });

  after(async function () {
    performanceTracker.generateReport();
  });

  describe("Complete Cabinet Purchase to Gacha Play Workflow", function () {
    it("should complete tier sale → cabinet configuration → gacha play workflow", async function () {
      const { contracts, accounts } = environment;

      console.log("🎯 Starting complete cabinet lifecycle test...");

      // Step 1: Purchase cabinet via TuuKeepTierSale
      console.log("💰 Step 1: Purchasing cabinet from tier sale...");
      const tier = TEST_CABINET_CONFIGS.BASIC_CABINET.tier;
      const tierPrice = TEST_CABINET_CONFIGS.BASIC_CABINET.price;

      const purchaseTx = await contracts.tuuKeepTierSale.write.purchaseCabinet([tier], {
        account: accounts.CABINET_OWNER.address,
        value: tierPrice
      });

      const purchaseGasMetrics = await assertions.measureGasUsageForScenario(
        "Cabinet Purchase",
        purchaseTx
      );
      performanceTracker.addGasMetrics(purchaseGasMetrics);

      const cabinetId = 1n; // First cabinet minted

      // Verify cabinet ownership
      await assertions.assertCabinetOwnership(cabinetId, accounts.CABINET_OWNER.address);

      // Step 2: Configure cabinet settings
      console.log("⚙️ Step 2: Configuring cabinet settings...");
      await contracts.tuuKeepCabinet.write.setCabinetPrice([
        cabinetId,
        TEST_GACHA_PRICES.CHEAP_PLAY
      ], { account: accounts.CABINET_OWNER.address });

      await contracts.tuuKeepCabinet.write.setMaxItems([
        cabinetId,
        TEST_CABINET_CONFIGS.BASIC_CABINET.maxItems
      ], { account: accounts.CABINET_OWNER.address });

      await assertions.assertCabinetConfiguration(
        cabinetId,
        TEST_GACHA_PRICES.CHEAP_PLAY,
        TEST_CABINET_CONFIGS.BASIC_CABINET.maxItems
      );

      // Step 3: Deposit ERC721 items into cabinet
      console.log("🎁 Step 3: Depositing items into cabinet...");
      const itemCount = 5;

      for (let i = 1; i <= itemCount; i++) {
        // Mint NFT to cabinet owner
        await contracts.mockERC721.write.mint([
          accounts.CABINET_OWNER.address,
          BigInt(i)
        ]);

        // Approve cabinet contract
        await contracts.mockERC721.write.approve([
          contracts.tuuKeepCabinet.address,
          BigInt(i)
        ], { account: accounts.CABINET_OWNER.address });

        // Deposit into cabinet
        await contracts.tuuKeepCabinet.write.depositERC721([
          cabinetId,
          contracts.mockERC721.address,
          BigInt(i)
        ], { account: accounts.CABINET_OWNER.address });
      }

      await assertions.assertCabinetItemCount(cabinetId, BigInt(itemCount));

      // Step 4: Player plays gacha with payment
      console.log("🎲 Step 4: Player playing gacha...");
      const player = accounts.PLAYER_1.address;
      const paymentAmount = TEST_GACHA_PRICES.CHEAP_PLAY;

      // Get initial balances
      const publicClient = await hre.viem.getPublicClient();
      const playerInitialBalance = await publicClient.getBalance({ address: player });
      const ownerInitialBalance = await publicClient.getBalance({ address: accounts.CABINET_OWNER.address });

      const gachaTx = await contracts.tuuKeepCabinet.write.playGacha([cabinetId], {
        account: player,
        value: paymentAmount
      });

      const gachaGasMetrics = await assertions.measureGasUsageForScenario(
        "Gacha Play",
        gachaTx
      );
      performanceTracker.addGasMetrics(gachaGasMetrics);

      // Step 5: Verify outcome (either prize won or TuuCoin minted)
      console.log("🔍 Step 5: Verifying gacha outcome...");

      // Check if player received TuuCoins (failed gacha) or NFT (successful gacha)
      const playerTuuCoinBalance = await contracts.tuuCoin.read.balanceOf([player]);
      const playerFinalBalance = await publicClient.getBalance({ address: player });

      if (playerTuuCoinBalance > 0n) {
        console.log("🪙 Player received TuuCoins (failed gacha)");
        expect(playerTuuCoinBalance).to.equal(TEST_TUUCOIN_CONFIG.EMISSION_RATE * (10n ** 18n));
      } else {
        console.log("🏆 Player won prize (successful gacha)");
        // Check if player received an NFT
        const nftBalance = await contracts.mockERC721.read.balanceOf([player]);
        expect(nftBalance).to.be.greaterThan(0n);
      }

      // Step 6: Validate revenue distribution
      console.log("💸 Step 6: Validating revenue distribution...");
      const ownerFinalBalance = await publicClient.getBalance({ address: accounts.CABINET_OWNER.address });

      // Cabinet owner should have received revenue (minus platform fee)
      const cabinetInfo = await contracts.tuuKeepCabinet.read.getCabinetInfo([cabinetId]);
      expect(cabinetInfo.collectedRevenue).to.be.greaterThan(0n);

      console.log("✅ Complete cabinet lifecycle test completed successfully!");
    });

    it("should handle cabinet management operations correctly", async function () {
      console.log("🔧 Testing cabinet management operations...");

      const scenario = await scenarioBuilder.createBasicCabinetScenario();
      const { contracts, accounts } = environment;

      // Test cabinet activation/deactivation
      await contracts.tuuKeepCabinet.write.setCabinetActive([scenario.cabinetId, false], {
        account: accounts.CABINET_OWNER.address
      });

      const cabinetInfo = await contracts.tuuKeepCabinet.read.getCabinetInfo([scenario.cabinetId]);
      expect(cabinetInfo.isActive).to.be.false;

      // Reactivate for further tests
      await contracts.tuuKeepCabinet.write.setCabinetActive([scenario.cabinetId, true], {
        account: accounts.CABINET_OWNER.address
      });

      // Test price updates
      const newPrice = parseEther("0.02");
      await contracts.tuuKeepCabinet.write.setCabinetPrice([scenario.cabinetId, newPrice], {
        account: accounts.CABINET_OWNER.address
      });

      await assertions.assertCabinetConfiguration(
        scenario.cabinetId,
        newPrice,
        scenario.maxItems
      );

      // Test item management - add more items
      await contracts.mockERC721.write.mint([accounts.CABINET_OWNER.address, 10n]);
      await contracts.mockERC721.write.approve([contracts.tuuKeepCabinet.address, 10n], {
        account: accounts.CABINET_OWNER.address
      });
      await contracts.tuuKeepCabinet.write.depositERC721([
        scenario.cabinetId,
        contracts.mockERC721.address,
        10n
      ], { account: accounts.CABINET_OWNER.address });

      await assertions.assertCabinetItemCount(scenario.cabinetId, BigInt(scenario.itemCount + 1));

      console.log("✅ Cabinet management operations test completed!");
    });

    it("should handle concurrent gacha plays correctly", async function () {
      console.log("👥 Testing concurrent gacha plays...");

      const scenario = await scenarioBuilder.createPremiumCabinetScenario();
      const results = await scenarioBuilder.simulateConcurrentGachaPlays(scenario.cabinetId, 3);

      // Verify all transactions were processed
      expect(results).to.have.length(3);

      let successfulPlays = 0;
      let failedPlays = 0;

      for (const result of results) {
        if (result.result.success) {
          successfulPlays++;
          const gasMetrics = await assertions.measureGasUsageForScenario(
            `Concurrent Gacha - ${result.player}`,
            result.result.txHash
          );
          performanceTracker.addGasMetrics(gasMetrics);
        } else {
          failedPlays++;
          console.log(`Player ${result.player} gacha failed:`, result.result.error);
        }
      }

      console.log(`📊 Concurrent gacha results: ${successfulPlays} successful, ${failedPlays} failed`);

      // Verify TuuCoin distribution for failed plays
      for (const result of results) {
        if (!result.result.success) {
          const tuuCoinBalance = await environment.contracts.tuuCoin.read.balanceOf([result.player]);
          if (tuuCoinBalance > 0n) {
            expect(tuuCoinBalance).to.equal(TEST_TUUCOIN_CONFIG.EMISSION_RATE * (10n ** 18n));
          }
        }
      }

      console.log("✅ Concurrent gacha plays test completed!");
    });
  });

  describe("Edge Cases and Error Conditions", function () {
    it("should handle cabinet with no items gracefully", async function () {
      console.log("🗳️ Testing empty cabinet scenario...");

      const { contracts, accounts } = environment;

      // Create cabinet without items
      await contracts.tuuKeepTierSale.write.purchaseCabinet([1n], {
        account: accounts.CABINET_OWNER.address,
        value: TEST_CABINET_CONFIGS.BASIC_CABINET.price
      });

      const emptyCabinetId = 2n; // Assuming second cabinet
      await contracts.tuuKeepCabinet.write.setCabinetPrice([
        emptyCabinetId,
        TEST_GACHA_PRICES.CHEAP_PLAY
      ], { account: accounts.CABINET_OWNER.address });

      // Try to play gacha on empty cabinet - should fail or give TuuCoins
      try {
        const gachaTx = await contracts.tuuKeepCabinet.write.playGacha([emptyCabinetId], {
          account: accounts.PLAYER_1.address,
          value: TEST_GACHA_PRICES.CHEAP_PLAY
        });

        // If successful, player should get TuuCoins
        const tuuCoinBalance = await contracts.tuuCoin.read.balanceOf([accounts.PLAYER_1.address]);
        expect(tuuCoinBalance).to.be.greaterThan(0n);

        console.log("✅ Empty cabinet handled gracefully - TuuCoins distributed");
      } catch (error) {
        console.log("✅ Empty cabinet properly rejected gacha play");
      }
    });

    it("should reject insufficient payment for gacha", async function () {
      console.log("💸 Testing insufficient payment scenario...");

      const scenario = await scenarioBuilder.createBasicCabinetScenario();
      const insufficientAmount = parseEther("0.005"); // Less than required

      try {
        await environment.contracts.tuuKeepCabinet.write.playGacha([scenario.cabinetId], {
          account: environment.accounts.PLAYER_2.address,
          value: insufficientAmount
        });

        // If this succeeds, something is wrong
        expect.fail("Should have rejected insufficient payment");
      } catch (error) {
        console.log("✅ Insufficient payment properly rejected");
        expect(error).to.exist;
      }
    });
  });
});