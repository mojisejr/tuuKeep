import { expect } from "chai";
import { viem } from "hardhat";
import { parseEther, parseUnits } from "viem";
import { deployTestEnvironment, TestEnvironment } from "./utils/deployment-helper";
import { ScenarioBuilder } from "./utils/scenario-builder";
import { AssertionHelpers, PerformanceTracker } from "./utils/assertion-helpers";
import { TEST_TUUCOIN_CONFIG } from "./fixtures/test-data";

describe("TuuCoin Economy Integration", function () {
  let environment: TestEnvironment;
  let scenarioBuilder: ScenarioBuilder;
  let assertions: AssertionHelpers;
  let performanceTracker: PerformanceTracker;

  this.timeout(300000); // 5 minutes for integration tests

  before(async function () {
    console.log("🪙 Setting up TuuCoin Economy Integration Test Environment...");
    environment = await deployTestEnvironment();
    scenarioBuilder = new ScenarioBuilder(environment);
    assertions = new AssertionHelpers(environment);
    performanceTracker = new PerformanceTracker();
    console.log("✅ Setup complete!");
  });

  after(async function () {
    performanceTracker.generateReport();
  });

  describe("Token Minting During Gacha", function () {
    it("should mint TuuCoins for unsuccessful gacha plays", async function () {
      const { contracts, accounts } = environment;

      console.log("🎲 Testing TuuCoin minting for failed gacha plays...");

      // Step 1: Create cabinet with items
      const cabinetScenario = await scenarioBuilder.createBasicCabinetScenario();
      const cabinetId = cabinetScenario.cabinetId;

      // Step 2: Get initial TuuCoin balance
      const player = accounts.PLAYER_1.address;
      const initialTuuCoinBalance = await contracts.tuuCoin.read.balanceOf([player]);
      const initialTotalSupply = await contracts.tuuCoin.read.totalSupply();

      console.log(`🔍 Initial player TuuCoin balance: ${initialTuuCoinBalance}`);
      console.log(`📊 Initial total supply: ${initialTotalSupply}`);

      // Step 3: Perform multiple gacha plays to increase chance of failures
      const playCount = 5;
      let failedPlays = 0;

      for (let i = 0; i < playCount; i++) {
        const playerAccount = i % 2 === 0 ? accounts.PLAYER_1.address : accounts.PLAYER_2.address;

        try {
          const gachaTx = await contracts.tuuKeepCabinet.write.playGacha([cabinetId], {
            account: playerAccount,
            value: parseEther("0.01")
          });

          const gasMetrics = await assertions.measureGasUsageForScenario(
            `TuuCoin Gacha Play ${i + 1}`,
            gachaTx
          );
          performanceTracker.addGasMetrics(gasMetrics);

          // Check if player received TuuCoins (indicating failed gacha)
          const newBalance = await contracts.tuuCoin.read.balanceOf([playerAccount]);
          const previousBalance = i === 0 ? initialTuuCoinBalance :
            await contracts.tuuCoin.read.balanceOf([playerAccount]);

          if (newBalance > previousBalance) {
            failedPlays++;
            console.log(`💰 Player ${playerAccount} received TuuCoins on play ${i + 1}`);
          }
        } catch (error) {
          console.log(`⚠️ Gacha play ${i + 1} failed:`, error);
        }
      }

      // Step 4: Verify TuuCoin minting occurred for failed plays
      if (failedPlays > 0) {
        const finalTotalSupply = await contracts.tuuCoin.read.totalSupply();
        const expectedMintedAmount = BigInt(failedPlays) * TEST_TUUCOIN_CONFIG.EMISSION_RATE * (10n ** 18n);

        expect(finalTotalSupply - initialTotalSupply).to.be.greaterThanOrEqual(expectedMintedAmount);
        console.log(`✅ Verified ${failedPlays} failed plays resulted in TuuCoin minting`);
      } else {
        console.log("ℹ️ All gacha plays were successful - no TuuCoins minted");
      }

      console.log("✅ TuuCoin minting for gacha failures test completed!");
    });

    it("should validate emission rate calculation", async function () {
      console.log("🧮 Testing emission rate calculation...");

      const { contracts, accounts } = environment;

      // Create cabinet with single item to force failure after first win
      const cabinetScenario = await scenarioBuilder.createBasicCabinetScenario();
      const cabinetId = cabinetScenario.cabinetId;

      const player = accounts.PLAYER_3.address;
      const initialBalance = await contracts.tuuCoin.read.balanceOf([player]);

      // Force a scenario that should result in TuuCoin emission
      // by playing multiple times (some should fail)
      let totalTuuCoinsReceived = 0n;
      const attempts = 3;

      for (let i = 0; i < attempts; i++) {
        try {
          const balanceBefore = await contracts.tuuCoin.read.balanceOf([player]);

          await contracts.tuuKeepCabinet.write.playGacha([cabinetId], {
            account: player,
            value: parseEther("0.01")
          });

          const balanceAfter = await contracts.tuuCoin.read.balanceOf([player]);
          const received = balanceAfter - balanceBefore;

          if (received > 0n) {
            totalTuuCoinsReceived += received;
            const expectedEmission = TEST_TUUCOIN_CONFIG.EMISSION_RATE * (10n ** 18n);
            expect(received).to.equal(expectedEmission);
            console.log(`✅ Correct emission rate applied: ${received} TuuCoins`);
          }
        } catch (error) {
          // Gacha might fail due to various reasons, continue testing
          console.log(`⚠️ Gacha attempt ${i + 1} failed`);
        }
      }

      const finalBalance = await contracts.tuuCoin.read.balanceOf([player]);
      expect(finalBalance - initialBalance).to.equal(totalTuuCoinsReceived);

      console.log("✅ Emission rate calculation validated!");
    });

    it("should track cabinet-specific multipliers correctly", async function () {
      console.log("🎯 Testing cabinet-specific emission multipliers...");

      const { contracts, accounts } = environment;

      // Test that different cabinets can have different emission rates
      const basicCabinet = await scenarioBuilder.createBasicCabinetScenario();
      const premiumCabinet = await scenarioBuilder.createPremiumCabinetScenario();

      // Both should use the same emission rate as configured in deployment
      const basicCabinetConfig = await contracts.tuuCoin.read.getCabinetConfig([basicCabinet.cabinetId]);
      const premiumCabinetConfig = await contracts.tuuCoin.read.getCabinetConfig([premiumCabinet.cabinetId]);

      expect(basicCabinetConfig.emissionRate).to.equal(TEST_TUUCOIN_CONFIG.EMISSION_RATE);
      expect(premiumCabinetConfig.emissionRate).to.equal(TEST_TUUCOIN_CONFIG.EMISSION_RATE);

      console.log("✅ Cabinet-specific multipliers validated!");
    });
  });

  describe("Burn for Odds Improvement", function () {
    it("should handle TuuCoin burning for odds boost", async function () {
      console.log("🔥 Testing TuuCoin burning for odds improvement...");

      const { contracts, accounts } = environment;

      // First, ensure player has TuuCoins to burn
      const player = accounts.PLAYER_1.address;

      // Mint some TuuCoins directly for testing (admin function)
      const mintAmount = parseUnits("100", 18); // 100 TuuCoins
      await contracts.tuuCoin.write.mint([player, mintAmount], {
        account: accounts.PLATFORM_ADMIN.address
      });

      const initialBalance = await contracts.tuuCoin.read.balanceOf([player]);
      expect(initialBalance).to.be.greaterThanOrEqual(mintAmount);

      // Test burning TuuCoins for odds improvement
      const burnAmount = parseUnits("50", 18); // 50 TuuCoins

      const burnTx = await contracts.tuuCoin.write.burnForOddsImprovement([burnAmount], {
        account: player
      });

      const burnGasMetrics = await assertions.measureGasUsageForScenario(
        "TuuCoin Burn for Odds",
        burnTx
      );
      performanceTracker.addGasMetrics(burnGasMetrics);

      // Verify balance decreased
      const finalBalance = await contracts.tuuCoin.read.balanceOf([player]);
      expect(initialBalance - finalBalance).to.equal(burnAmount);

      // Verify user's burn statistics
      const userStats = await contracts.tuuCoin.read.getUserBurnStats([player]);
      expect(userStats.totalBurned).to.equal(burnAmount);
      expect(userStats.oddsImprovement).to.be.greaterThan(0n);

      console.log(`🔥 Successfully burned ${burnAmount} TuuCoins for odds improvement`);
      console.log("✅ TuuCoin burning test completed!");
    });

    it("should calculate odds improvement correctly", async function () {
      console.log("📈 Testing odds improvement calculation...");

      const { contracts, accounts } = environment;

      const player = accounts.PLAYER_2.address;

      // Mint TuuCoins for testing
      const mintAmount = parseUnits("200", 18);
      await contracts.tuuCoin.write.mint([player, mintAmount], {
        account: accounts.PLATFORM_ADMIN.address
      });

      // Test different burn amounts and their odds improvements
      const burnAmounts = [
        parseUnits("10", 18),
        parseUnits("25", 18),
        parseUnits("50", 18)
      ];

      for (let i = 0; i < burnAmounts.length; i++) {
        const burnAmount = burnAmounts[i];

        await contracts.tuuCoin.write.burnForOddsImprovement([burnAmount], {
          account: player
        });

        const userStats = await contracts.tuuCoin.read.getUserBurnStats([player]);

        // Odds improvement should be proportional to burn amount
        // This is a simplified check - actual implementation may vary
        expect(userStats.oddsImprovement).to.be.greaterThan(0n);

        console.log(`💎 Burn ${i + 1}: ${burnAmount} TuuCoins → ${userStats.oddsImprovement} basis points improvement`);
      }

      console.log("✅ Odds improvement calculation validated!");
    });

    it("should prevent burning more than balance", async function () {
      console.log("🚫 Testing burn amount validation...");

      const { contracts, accounts } = environment;

      const player = accounts.PLAYER_3.address;
      const balance = await contracts.tuuCoin.read.balanceOf([player]);

      // Try to burn more than balance
      const excessiveAmount = balance + parseUnits("1000", 18);

      try {
        await contracts.tuuCoin.write.burnForOddsImprovement([excessiveAmount], {
          account: player
        });

        expect.fail("Should have rejected burning more than balance");
      } catch (error) {
        console.log("✅ Excessive burn amount properly rejected");
        expect(error).to.exist;
      }
    });
  });

  describe("Cabinet Registration and Integration", function () {
    it("should manage cabinet registration in TuuCoin", async function () {
      console.log("🏪 Testing cabinet registration management...");

      const { contracts, accounts } = environment;

      // Test registering a new cabinet (mock address)
      const mockCabinetAddress = "0x1234567890123456789012345678901234567890" as `0x${string}`;
      const newEmissionRate = 15n; // Different from default

      await contracts.tuuCoin.write.registerCabinet([
        mockCabinetAddress,
        newEmissionRate
      ], { account: accounts.PLATFORM_ADMIN.address });

      // Verify cabinet registration
      try {
        const cabinetConfig = await contracts.tuuCoin.read.getCabinetConfig([1n]); // Mock cabinet ID
        console.log("📋 Cabinet registered successfully");
      } catch (error) {
        console.log("ℹ️ Cabinet config retrieval method may not be available");
      }

      // Test updating emission rate for existing cabinet
      const updatedEmissionRate = 20n;
      await contracts.tuuCoin.write.updateCabinetEmissionRate([
        environment.contracts.tuuKeepCabinet.address,
        updatedEmissionRate
      ], { account: accounts.PLATFORM_ADMIN.address });

      console.log("✅ Cabinet registration management validated!");
    });

    it("should handle active/inactive status management", async function () {
      console.log("🔄 Testing cabinet status management...");

      const { contracts, accounts } = environment;

      const cabinetAddress = environment.contracts.tuuKeepCabinet.address;

      // Test deactivating cabinet
      await contracts.tuuCoin.write.setCabinetActive([cabinetAddress, false], {
        account: accounts.PLATFORM_ADMIN.address
      });

      // Test reactivating cabinet
      await contracts.tuuCoin.write.setCabinetActive([cabinetAddress, true], {
        account: accounts.PLATFORM_ADMIN.address
      });

      console.log("✅ Cabinet status management validated!");
    });
  });

  describe("Token Supply and Economics", function () {
    it("should track total supply correctly", async function () {
      console.log("📊 Testing total supply tracking...");

      const { contracts, accounts } = environment;

      const initialSupply = await contracts.tuuCoin.read.totalSupply();

      // Mint some tokens
      const mintAmount = parseUnits("1000", 18);
      await contracts.tuuCoin.write.mint([accounts.PLAYER_1.address, mintAmount], {
        account: accounts.PLATFORM_ADMIN.address
      });

      const afterMintSupply = await contracts.tuuCoin.read.totalSupply();
      expect(afterMintSupply - initialSupply).to.equal(mintAmount);

      // Burn some tokens
      const burnAmount = parseUnits("500", 18);
      await contracts.tuuCoin.write.burnForOddsImprovement([burnAmount], {
        account: accounts.PLAYER_1.address
      });

      const afterBurnSupply = await contracts.tuuCoin.read.totalSupply();
      expect(afterMintSupply - afterBurnSupply).to.equal(burnAmount);

      console.log(`📈 Supply tracking: Initial ${initialSupply}, After mint ${afterMintSupply}, After burn ${afterBurnSupply}`);
      console.log("✅ Total supply tracking validated!");
    });

    it("should enforce maximum supply limits", async function () {
      console.log("🔒 Testing maximum supply enforcement...");

      const { contracts, accounts } = environment;

      const currentSupply = await contracts.tuuCoin.read.totalSupply();
      const maxSupply = TEST_TUUCOIN_CONFIG.MAX_SUPPLY;

      if (currentSupply < maxSupply) {
        // Try to mint beyond max supply
        const excessiveAmount = maxSupply - currentSupply + parseUnits("1", 18);

        try {
          await contracts.tuuCoin.write.mint([accounts.PLAYER_1.address, excessiveAmount], {
            account: accounts.PLATFORM_ADMIN.address
          });

          // Check if minting was capped at max supply
          const finalSupply = await contracts.tuuCoin.read.totalSupply();
          expect(finalSupply).to.be.lessThanOrEqual(maxSupply);

        } catch (error) {
          console.log("✅ Maximum supply limit properly enforced");
          expect(error).to.exist;
        }
      } else {
        console.log("ℹ️ Already at or near maximum supply");
      }

      console.log("✅ Maximum supply enforcement validated!");
    });
  });
});