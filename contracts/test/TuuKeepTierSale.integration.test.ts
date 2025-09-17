import { expect } from "chai";
import { viem } from "hardhat";
import { getAddress, parseEther, formatEther } from "viem";

describe("TuuKeepTierSale Integration Tests", function () {
  // Test fixture for setting up contracts
  async function deployTierSaleFixture() {
    const [deployer, admin, buyer1, buyer2, buyer3, platformTreasury] = await viem.getWalletClients();

    // Deploy access control
    const accessControl = await viem.deployContract("TuuKeepAccessControl", [deployer.account.address]);

    // Deploy randomness
    const randomness = await viem.deployContract("Randomness", [deployer.account.address]);

    // Deploy TuuCoin
    const tuuCoin = await viem.deployContract("TuuCoin", [
      accessControl.address,
      deployer.account.address,
      parseEther("1000000"), // max supply
    ]);

    // Deploy TuuKeepCabinet
    const cabinet = await viem.deployContract("TuuKeepCabinet", [
      accessControl.address,
      tuuCoin.address,
      randomness.address,
      platformTreasury.account.address,
    ]);

    // Deploy TuuKeepTierSale
    const tierSale = await viem.deployContract("TuuKeepTierSale", [
      cabinet.address,
      platformTreasury.account.address,
      admin.account.address,
    ]);

    // Setup roles
    await accessControl.write.grantRole([
      await accessControl.read.MINTER_ROLE(),
      tierSale.address,
    ]);

    await cabinet.write.grantRole([
      await cabinet.read.MINTER_ROLE(),
      tierSale.address,
    ]);

    // Buyers already have sufficient ETH from hardhat accounts

    return {
      deployer,
      admin,
      buyer1,
      buyer2,
      buyer3,
      platformTreasury,
      accessControl,
      randomness,
      tuuCoin,
      cabinet,
      tierSale,
    };
  }

  // Test fixture with Phase 1 setup
  async function deployPhase1Fixture() {
    const contracts = await deployTierSaleFixture();
    const { tierSale, admin } = contracts;

    const currentTime = await time.latest();
    const phaseStartTime = currentTime + 300; // Start in 5 minutes
    const basePrice = parseEther("20"); // 20 KUB base price

    // Create Phase 1: Genesis Sale
    await tierSale.write.createSalePhase([
      "Genesis Sale",
      BigInt(phaseStartTime),
      0n, // No end time
      50n, // 50 cabinets total
      basePrice,
    ], { account: admin.account });

    const phaseId = 0n;

    // Add Super Early Bird tier (70% discount)
    await tierSale.write.addTierToPhase([
      phaseId,
      "Super Early Bird",
      5n, // 5 cabinets
      7000n, // 70% discount
      BigInt(phaseStartTime),
      0n, // No end time
    ], { account: admin.account });

    // Add Early Bird tier (20% discount)
    await tierSale.write.addTierToPhase([
      phaseId,
      "Early Bird",
      20n, // 20 cabinets
      2000n, // 20% discount
      BigInt(phaseStartTime),
      BigInt(phaseStartTime + 5 * 24 * 3600), // 5 days
    ], { account: admin.account });

    // Add Regular tier (no discount)
    await tierSale.write.addTierToPhase([
      phaseId,
      "Regular",
      25n, // 25 cabinets
      0n, // No discount
      BigInt(phaseStartTime),
      0n, // No end time
    ], { account: admin.account });

    return { ...contracts, phaseId, phaseStartTime, basePrice };
  }

  describe("Contract Deployment", function () {
    it("Should deploy all contracts successfully", async function () {
      const { tierSale, cabinet, platformTreasury } = await loadFixture(deployTierSaleFixture);

      expect(await tierSale.read.cabinetContract()).to.equal(cabinet.address);
      expect(await tierSale.read.platformTreasury()).to.equal(platformTreasury.account.address);
      expect(await tierSale.read.platformFeeRate()).to.equal(500n); // 5%
    });

    it("Should grant correct roles to admin", async function () {
      const { tierSale, admin } = await loadFixture(deployTierSaleFixture);

      const defaultAdminRole = await tierSale.read.DEFAULT_ADMIN_ROLE();
      const saleManagerRole = await tierSale.read.SALE_MANAGER_ROLE();
      const platformAdminRole = await tierSale.read.PLATFORM_ADMIN_ROLE();

      expect(await tierSale.read.hasRole([defaultAdminRole, admin.account.address])).to.be.true;
      expect(await tierSale.read.hasRole([saleManagerRole, admin.account.address])).to.be.true;
      expect(await tierSale.read.hasRole([platformAdminRole, admin.account.address])).to.be.true;
    });
  });

  describe("Phase Management", function () {
    it("Should create sale phase successfully", async function () {
      const { tierSale, admin } = await loadFixture(deployTierSaleFixture);

      const currentTime = await time.latest();
      const startTime = currentTime + 3600; // Start in 1 hour
      const basePrice = parseEther("20");

      await tierSale.write.createSalePhase([
        "Test Phase",
        BigInt(startTime),
        0n,
        100n,
        basePrice,
      ], { account: admin.account });

      const totalPhases = await tierSale.read.getTotalPhases();
      expect(totalPhases).to.equal(1n);

      const [phase] = await tierSale.read.getPhaseInfo([0n]);
      expect(phase.name).to.equal("Test Phase");
      expect(phase.totalCabinets).to.equal(100n);
      expect(phase.basePrice).to.equal(basePrice);
      expect(phase.isActive).to.be.true;
    });

    it("Should add tiers to phase successfully", async function () {
      const { tierSale, admin } = await loadFixture(deployPhase1Fixture);

      const [phase, tiers] = await tierSale.read.getPhaseInfo([0n]);
      expect(tiers).to.have.lengthOf(3);

      // Super Early Bird (70% discount)
      expect(tiers[0].name).to.equal("Super Early Bird");
      expect(tiers[0].maxQuantity).to.equal(5n);
      expect(tiers[0].discountBps).to.equal(7000n);
      expect(tiers[0].price).to.equal(parseEther("6")); // 20 - 70% = 6 KUB

      // Early Bird (20% discount)
      expect(tiers[1].name).to.equal("Early Bird");
      expect(tiers[1].maxQuantity).to.equal(20n);
      expect(tiers[1].discountBps).to.equal(2000n);
      expect(tiers[1].price).to.equal(parseEther("16")); // 20 - 20% = 16 KUB

      // Regular (no discount)
      expect(tiers[2].name).to.equal("Regular");
      expect(tiers[2].maxQuantity).to.equal(25n);
      expect(tiers[2].discountBps).to.equal(0n);
      expect(tiers[2].price).to.equal(parseEther("20")); // 20 KUB
    });
  });

  describe("Tier Progression Logic", function () {
    it("Should return correct current tier", async function () {
      const { tierSale, phaseStartTime } = await loadFixture(deployPhase1Fixture);

      // Fast forward to phase start
      await time.increaseTo(phaseStartTime);

      const currentTier = await tierSale.read.getCurrentTierInfo([0n]);
      expect(currentTier.name).to.equal("Super Early Bird");
      expect(currentTier.price).to.equal(parseEther("6"));
    });

    it("Should progress to next tier when current tier is sold out", async function () {
      const { tierSale, buyer1, phaseStartTime } = await loadFixture(deployPhase1Fixture);

      // Fast forward to phase start
      await time.increaseTo(phaseStartTime);

      // Buy all 5 Super Early Bird cabinets
      for (let i = 0; i < 5; i++) {
        await tierSale.write.purchaseCabinet([
          0n,
          `Super Early Bird Cabinet ${i + 1}`,
        ], {
          account: buyer1.account,
          value: parseEther("6"),
        });
      }

      // Current tier should now be Early Bird
      const currentTier = await tierSale.read.getCurrentTierInfo([0n]);
      expect(currentTier.name).to.equal("Early Bird");
      expect(currentTier.price).to.equal(parseEther("16"));
    });

    it("Should respect tier time constraints", async function () {
      const { tierSale, phaseStartTime } = await loadFixture(deployPhase1Fixture);

      // Buy out Super Early Bird tier first
      await time.increaseTo(phaseStartTime);
      const buyer = (await viem.getWalletClients())[1];

      for (let i = 0; i < 5; i++) {
        await tierSale.write.purchaseCabinet([
          0n,
          `Cabinet ${i + 1}`,
        ], {
          account: buyer.account,
          value: parseEther("6"),
        });
      }

      // Fast forward past Early Bird end time
      await time.increaseTo(phaseStartTime + 6 * 24 * 3600); // 6 days

      // Should skip Early Bird and go to Regular
      const currentTier = await tierSale.read.getCurrentTierInfo([0n]);
      expect(currentTier.name).to.equal("Regular");
    });
  });

  describe("Cabinet Purchase Flow", function () {
    it("Should purchase cabinet successfully with correct payment", async function () {
      const { tierSale, cabinet, buyer1, phaseStartTime } = await loadFixture(deployPhase1Fixture);

      await time.increaseTo(phaseStartTime);

      const initialBalance = await viem.getPublicClient().getBalance({
        address: buyer1.account.address,
      });

      const cabinetId = await tierSale.write.purchaseCabinet([
        0n,
        "My First Cabinet",
      ], {
        account: buyer1.account,
        value: parseEther("6"), // Super Early Bird price
      });

      // Verify cabinet was minted
      const owner = await cabinet.read.ownerOf([0n]);
      expect(owner.toLowerCase()).to.equal(buyer1.account.address.toLowerCase());

      // Verify purchase was recorded
      const totalPurchases = await tierSale.read.getTotalPurchases();
      expect(totalPurchases).to.equal(1n);

      const purchase = await tierSale.read.purchases([0n]);
      expect(purchase.buyer.toLowerCase()).to.equal(buyer1.account.address.toLowerCase());
      expect(purchase.price).to.equal(parseEther("6"));
    });

    it("Should handle excess payment correctly", async function () {
      const { tierSale, buyer1, phaseStartTime } = await loadFixture(deployPhase1Fixture);

      await time.increaseTo(phaseStartTime);

      const initialBalance = await viem.getPublicClient().getBalance({
        address: buyer1.account.address,
      });

      await tierSale.write.purchaseCabinet([
        0n,
        "Test Cabinet",
      ], {
        account: buyer1.account,
        value: parseEther("10"), // Pay 10 KUB for 6 KUB cabinet
      });

      const finalBalance = await viem.getPublicClient().getBalance({
        address: buyer1.account.address,
      });

      // Should have paid exactly 6 KUB plus gas
      const spent = initialBalance - finalBalance;
      expect(spent).to.be.lessThan(parseEther("6.1")); // 6 KUB + reasonable gas
    });

    it("Should reject insufficient payment", async function () {
      const { tierSale, buyer1, phaseStartTime } = await loadFixture(deployPhase1Fixture);

      await time.increaseTo(phaseStartTime);

      await expect(
        tierSale.write.purchaseCabinet([
          0n,
          "Test Cabinet",
        ], {
          account: buyer1.account,
          value: parseEther("3"), // Too low for 6 KUB cabinet
        })
      ).to.be.rejectedWith("InsufficientPayment");
    });

    it("Should distribute platform fees correctly", async function () {
      const { tierSale, platformTreasury, phaseStartTime } = await loadFixture(deployPhase1Fixture);

      await time.increaseTo(phaseStartTime);

      const initialTreasuryBalance = await viem.getPublicClient().getBalance({
        address: platformTreasury.account.address,
      });

      const buyer = (await viem.getWalletClients())[1];
      await tierSale.write.purchaseCabinet([
        0n,
        "Test Cabinet",
      ], {
        account: buyer.account,
        value: parseEther("6"),
      });

      const finalTreasuryBalance = await viem.getPublicClient().getBalance({
        address: platformTreasury.account.address,
      });

      // Platform should receive 5% of 6 KUB = 0.3 KUB
      const expectedFee = parseEther("6") * 500n / 10000n;
      const actualFee = finalTreasuryBalance - initialTreasuryBalance;
      expect(actualFee).to.equal(expectedFee);
    });
  });

  describe("Revenue Management", function () {
    it("Should track total revenue correctly", async function () {
      const { tierSale, phaseStartTime } = await loadFixture(deployPhase1Fixture);

      await time.increaseTo(phaseStartTime);

      const buyers = await viem.getWalletClients();

      // Purchase 3 cabinets
      for (let i = 0; i < 3; i++) {
        await tierSale.write.purchaseCabinet([
          0n,
          `Cabinet ${i + 1}`,
        ], {
          account: buyers[i + 1].account,
          value: parseEther("6"),
        });
      }

      const totalRevenue = await tierSale.read.totalRevenue();
      // Each purchase: 6 KUB - 5% fee = 5.7 KUB
      // 3 purchases * 5.7 KUB = 17.1 KUB
      const expectedRevenue = parseEther("6") * 3n * 9500n / 10000n;
      expect(totalRevenue).to.equal(expectedRevenue);
    });

    it("Should allow admin to withdraw revenue", async function () {
      const { tierSale, admin, phaseStartTime } = await loadFixture(deployPhase1Fixture);

      await time.increaseTo(phaseStartTime);

      const buyer = (await viem.getWalletClients())[1];
      await tierSale.write.purchaseCabinet([
        0n,
        "Test Cabinet",
      ], {
        account: buyer.account,
        value: parseEther("6"),
      });

      const contractBalance = await tierSale.read.getContractBalance();
      expect(contractBalance).to.be.greaterThan(0n);

      const initialAdminBalance = await viem.getPublicClient().getBalance({
        address: admin.account.address,
      });

      await tierSale.write.withdrawRevenue([
        admin.account.address,
        contractBalance,
      ], { account: admin.account });

      const finalAdminBalance = await viem.getPublicClient().getBalance({
        address: admin.account.address,
      });
      expect(finalAdminBalance).to.be.greaterThan(initialAdminBalance);
    });
  });

  describe("Error Handling", function () {
    it("Should reject purchase before phase start", async function () {
      const { tierSale, buyer1 } = await loadFixture(deployPhase1Fixture);

      await expect(
        tierSale.write.purchaseCabinet([
          0n,
          "Test Cabinet",
        ], {
          account: buyer1.account,
          value: parseEther("6"),
        })
      ).to.be.rejectedWith("PhaseNotActive");
    });

    it("Should reject purchase when tier is sold out", async function () {
      const { tierSale, phaseStartTime } = await loadFixture(deployPhase1Fixture);

      await time.increaseTo(phaseStartTime);

      const buyers = await viem.getWalletClients();

      // Buy all 5 Super Early Bird cabinets
      for (let i = 0; i < 5; i++) {
        await tierSale.write.purchaseCabinet([
          0n,
          `Cabinet ${i + 1}`,
        ], {
          account: buyers[i + 1].account,
          value: parseEther("6"),
        });
      }

      // Try to buy one more Early Bird at Super Early Bird price
      await expect(
        tierSale.write.purchaseCabinet([
          0n,
          "Failed Cabinet",
        ], {
          account: buyers[6].account,
          value: parseEther("6"), // Wrong price for Early Bird
        })
      ).to.be.rejectedWith("InsufficientPayment");
    });

    it("Should reject purchase when phase limit exceeded", async function () {
      const { tierSale, phaseStartTime } = await loadFixture(deployPhase1Fixture);

      await time.increaseTo(phaseStartTime);

      const buyers = await viem.getWalletClients();

      // Buy all 50 cabinets (5 + 20 + 25)
      // Super Early Bird: 5 × 6 KUB
      for (let i = 0; i < 5; i++) {
        await tierSale.write.purchaseCabinet([
          0n,
          `Super Early ${i + 1}`,
        ], {
          account: buyers[i % buyers.length].account,
          value: parseEther("6"),
        });
      }

      // Early Bird: 20 × 16 KUB
      for (let i = 0; i < 20; i++) {
        await tierSale.write.purchaseCabinet([
          0n,
          `Early Bird ${i + 1}`,
        ], {
          account: buyers[i % buyers.length].account,
          value: parseEther("16"),
        });
      }

      // Regular: 25 × 20 KUB
      for (let i = 0; i < 25; i++) {
        await tierSale.write.purchaseCabinet([
          0n,
          `Regular ${i + 1}`,
        ], {
          account: buyers[i % buyers.length].account,
          value: parseEther("20"),
        });
      }

      // Try to buy one more
      await expect(
        tierSale.write.purchaseCabinet([
          0n,
          "Failed Cabinet",
        ], {
          account: buyers[0].account,
          value: parseEther("20"),
        })
      ).to.be.rejectedWith("PhaseLimitExceeded");
    });
  });

  describe("Administrative Functions", function () {
    it("Should pause and unpause contract", async function () {
      const { tierSale, admin, buyer1, phaseStartTime } = await loadFixture(deployPhase1Fixture);

      await time.increaseTo(phaseStartTime);

      // Pause contract
      await tierSale.write.pause([], { account: admin.account });

      // Should reject purchases when paused
      await expect(
        tierSale.write.purchaseCabinet([
          0n,
          "Test Cabinet",
        ], {
          account: buyer1.account,
          value: parseEther("6"),
        })
      ).to.be.rejectedWith("Pausable: paused");

      // Unpause contract
      await tierSale.write.unpause([], { account: admin.account });

      // Should work after unpause
      await tierSale.write.purchaseCabinet([
        0n,
        "Test Cabinet",
      ], {
        account: buyer1.account,
        value: parseEther("6"),
      });
    });

    it("Should update platform fee rate", async function () {
      const { tierSale, admin } = await loadFixture(deployPhase1Fixture);

      await tierSale.write.setPlatformFeeRate([1000n], { account: admin.account }); // 10%

      const newFeeRate = await tierSale.read.platformFeeRate();
      expect(newFeeRate).to.equal(1000n);
    });

    it("Should activate and deactivate phases", async function () {
      const { tierSale, admin } = await loadFixture(deployPhase1Fixture);

      // Deactivate phase
      await tierSale.write.deactivatePhase([0n], { account: admin.account });

      const [phase] = await tierSale.read.getPhaseInfo([0n]);
      expect(phase.isActive).to.be.false;

      // Reactivate phase
      await tierSale.write.activatePhase([0n], { account: admin.account });

      const [reactivatedPhase] = await tierSale.read.getPhaseInfo([0n]);
      expect(reactivatedPhase.isActive).to.be.true;
    });
  });

  describe("Gas Usage Optimization", function () {
    it("Should use less than 200k gas per purchase", async function () {
      const { tierSale, buyer1, phaseStartTime } = await loadFixture(deployPhase1Fixture);

      await time.increaseTo(phaseStartTime);

      const tx = await tierSale.write.purchaseCabinet([
        0n,
        "Gas Test Cabinet",
      ], {
        account: buyer1.account,
        value: parseEther("6"),
      });

      const receipt = await viem.getPublicClient().getTransactionReceipt({ hash: tx });
      console.log(`Gas used for purchase: ${receipt.gasUsed}`);

      // Should be under 200k gas
      expect(receipt.gasUsed).to.be.lessThan(200000n);
    });
  });

  describe("End-to-End Phase 1 Simulation", function () {
    it("Should complete Phase 1 with correct revenue distribution", async function () {
      const { tierSale, platformTreasury, phaseStartTime } = await loadFixture(deployPhase1Fixture);

      await time.increaseTo(phaseStartTime);

      const buyers = await viem.getWalletClients();
      let totalExpectedRevenue = 0n;

      // Super Early Bird: 5 × 6 KUB = 30 KUB
      for (let i = 0; i < 5; i++) {
        await tierSale.write.purchaseCabinet([
          0n,
          `Super Early ${i + 1}`,
        ], {
          account: buyers[i % buyers.length].account,
          value: parseEther("6"),
        });
        totalExpectedRevenue += parseEther("6");
      }

      // Early Bird: 20 × 16 KUB = 320 KUB
      for (let i = 0; i < 20; i++) {
        await tierSale.write.purchaseCabinet([
          0n,
          `Early Bird ${i + 1}`,
        ], {
          account: buyers[i % buyers.length].account,
          value: parseEther("16"),
        });
        totalExpectedRevenue += parseEther("16");
      }

      // Regular: 25 × 20 KUB = 500 KUB
      for (let i = 0; i < 25; i++) {
        await tierSale.write.purchaseCabinet([
          0n,
          `Regular ${i + 1}`,
        ], {
          account: buyers[i % buyers.length].account,
          value: parseEther("20"),
        });
        totalExpectedRevenue += parseEther("20");
      }

      // Total: 30 + 320 + 500 = 850 KUB
      expect(totalExpectedRevenue).to.equal(parseEther("850"));

      const [finalPhase] = await tierSale.read.getPhaseInfo([0n]);
      expect(finalPhase.soldCabinets).to.equal(50n);

      const totalPurchases = await tierSale.read.getTotalPurchases();
      expect(totalPurchases).to.equal(50n);

      console.log(`Phase 1 completed: 50 cabinets sold for ${formatEther(totalExpectedRevenue)} KUB total revenue`);
    });
  });
});