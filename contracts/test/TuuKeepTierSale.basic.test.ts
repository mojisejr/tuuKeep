import { expect } from "chai";
import { viem } from "hardhat";
import { parseEther, formatEther } from "viem";

describe("TuuKeepTierSale Basic Tests", function () {
  let deployer: any, admin: any, buyer1: any, platformTreasury: any;
  let accessControl: any, randomness: any, tuuCoin: any, cabinet: any, tierSale: any;

  before(async function () {
    [deployer, admin, buyer1, platformTreasury] = await viem.getWalletClients();

    // Deploy access control
    accessControl = await viem.deployContract("TuuKeepAccessControl", [deployer.account.address]);

    // Deploy randomness
    randomness = await viem.deployContract("Randomness", [deployer.account.address]);

    // Deploy TuuCoin
    tuuCoin = await viem.deployContract("TuuCoin", [
      accessControl.address,
      deployer.account.address,
      parseEther("1000000"), // max supply
    ]);

    // Deploy TuuKeepCabinet
    cabinet = await viem.deployContract("TuuKeepCabinet", [
      accessControl.address,
      tuuCoin.address,
      randomness.address,
      platformTreasury.account.address,
    ]);

    // Deploy TuuKeepTierSale
    tierSale = await viem.deployContract("TuuKeepTierSale", [
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
  });

  describe("Contract Deployment", function () {
    it("Should deploy TuuKeepTierSale successfully", async function () {
      expect(await tierSale.read.cabinetContract()).to.equal(cabinet.address);
      expect(await tierSale.read.platformTreasury()).to.equal(platformTreasury.account.address);
      expect(await tierSale.read.platformFeeRate()).to.equal(500n); // 5%
    });

    it("Should grant correct roles to admin", async function () {
      const defaultAdminRole = await tierSale.read.DEFAULT_ADMIN_ROLE();
      const saleManagerRole = await tierSale.read.SALE_MANAGER_ROLE();
      const platformAdminRole = await tierSale.read.PLATFORM_ADMIN_ROLE();

      expect(await tierSale.read.hasRole([defaultAdminRole, admin.account.address])).to.be.true;
      expect(await tierSale.read.hasRole([saleManagerRole, admin.account.address])).to.be.true;
      expect(await tierSale.read.hasRole([platformAdminRole, admin.account.address])).to.be.true;
    });
  });

  describe("Phase and Tier Management", function () {
    it("Should create sale phase successfully", async function () {
      const currentTime = Math.floor(Date.now() / 1000);
      const startTime = currentTime + 60; // Start in 1 minute
      const basePrice = parseEther("20");

      await tierSale.write.createSalePhase([
        "Genesis Sale",
        BigInt(startTime),
        0n, // No end time
        50n, // 50 cabinets total
        basePrice,
      ], { account: admin.account });

      const totalPhases = await tierSale.read.getTotalPhases();
      expect(totalPhases).to.equal(1n);

      const [phase] = await tierSale.read.getPhaseInfo([0n]);
      expect(phase.name).to.equal("Genesis Sale");
      expect(phase.totalCabinets).to.equal(50n);
      expect(phase.basePrice).to.equal(basePrice);
      expect(phase.isActive).to.be.true;
    });

    it("Should add tiers to phase successfully", async function () {
      const phaseId = 0n;
      const currentTime = Math.floor(Date.now() / 1000);

      // Add Super Early Bird tier (70% discount)
      await tierSale.write.addTierToPhase([
        phaseId,
        "Super Early Bird",
        5n, // 5 cabinets
        7000n, // 70% discount
        BigInt(currentTime),
        0n, // No end time
      ], { account: admin.account });

      // Add Early Bird tier (20% discount)
      await tierSale.write.addTierToPhase([
        phaseId,
        "Early Bird",
        20n, // 20 cabinets
        2000n, // 20% discount
        BigInt(currentTime),
        0n, // No end time
      ], { account: admin.account });

      // Add Regular tier (no discount)
      await tierSale.write.addTierToPhase([
        phaseId,
        "Regular",
        25n, // 25 cabinets
        0n, // No discount
        BigInt(currentTime),
        0n, // No end time
      ], { account: admin.account });

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

  describe("Cabinet Purchase", function () {
    it("Should get current tier correctly", async function () {
      const currentTier = await tierSale.read.getCurrentTierInfo([0n]);
      expect(currentTier.name).to.equal("Super Early Bird");
      expect(currentTier.price).to.equal(parseEther("6"));
    });

    it("Should purchase cabinet successfully", async function () {
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

    it("Should reject insufficient payment", async function () {
      await expect(
        tierSale.write.purchaseCabinet([
          0n,
          "Failed Cabinet",
        ], {
          account: buyer1.account,
          value: parseEther("3"), // Too low for 6 KUB cabinet
        })
      ).to.be.rejectedWith("InsufficientPayment");
    });

    it("Should track gas usage for purchase", async function () {
      const tx = await tierSale.write.purchaseCabinet([
        0n,
        "Gas Test Cabinet",
      ], {
        account: buyer1.account,
        value: parseEther("6"),
      });

      const receipt = await viem.getPublicClient().getTransactionReceipt({ hash: tx });
      console.log(`Gas used for purchase: ${receipt.gasUsed}`);

      // Should be under 200k gas (our target)
      expect(receipt.gasUsed).to.be.lessThan(200000n);
    });
  });

  describe("Revenue Management", function () {
    it("Should track total revenue correctly", async function () {
      const totalRevenue = await tierSale.read.totalRevenue();
      // Should have revenue from 2 purchases: 2 * (6 KUB - 5% fee) = 2 * 5.7 = 11.4 KUB
      const expectedRevenue = parseEther("6") * 2n * 9500n / 10000n;
      expect(totalRevenue).to.equal(expectedRevenue);
    });

    it("Should allow admin to withdraw revenue", async function () {
      const contractBalance = await tierSale.read.getContractBalance();
      expect(contractBalance).to.be.greaterThan(0n);

      await tierSale.write.withdrawRevenue([
        admin.account.address,
        contractBalance,
      ], { account: admin.account });

      const newBalance = await tierSale.read.getContractBalance();
      expect(newBalance).to.equal(0n);
    });
  });

  describe("Administrative Functions", function () {
    it("Should update platform fee rate", async function () {
      await tierSale.write.setPlatformFeeRate([1000n], { account: admin.account }); // 10%

      const newFeeRate = await tierSale.read.platformFeeRate();
      expect(newFeeRate).to.equal(1000n);
    });

    it("Should pause and unpause contract", async function () {
      // Pause contract
      await tierSale.write.pause([], { account: admin.account });

      // Should reject purchases when paused
      await expect(
        tierSale.write.purchaseCabinet([
          0n,
          "Paused Test",
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
        "Unpaused Test",
      ], {
        account: buyer1.account,
        value: parseEther("6"),
      });
    });
  });
});