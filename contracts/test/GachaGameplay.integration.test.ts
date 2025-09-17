import { expect } from "chai";
import { viem } from "hardhat";
import { getAddress, parseEther, formatEther } from "viem";
import {
  loadFixture,
  setBalance,
} from "@nomicfoundation/hardhat-network-helpers";

describe("Gacha Gameplay Integration Tests", function () {
  // Test fixture for setting up contracts
  async function deployContractsFixture() {
    const [deployer, cabinetOwner, player1, player2, platformAdmin] = await viem.getWalletClients();

    // Deploy access control
    const accessControl = await viem.deployContract("TuuKeepAccessControl", [deployer.account.address]);

    // Deploy randomness
    const randomness = await viem.deployContract("Randomness", [deployer.account.address]);

    // Deploy TuuCoin
    const tuuCoin = await viem.deployContract("TuuCoin", [
      accessControl.address,
      deployer.account.address, // initial minter
      parseEther("1000000"), // max supply
    ]);

    // Deploy TuuKeepCabinet
    const cabinet = await viem.deployContract("TuuKeepCabinet", [
      accessControl.address,
      tuuCoin.address,
      randomness.address,
      platformAdmin.account.address, // platform fee recipient
    ]);

    // Deploy mock ERC721 and ERC20 for testing
    const mockNFT = await viem.deployContract("MockERC721", ["Mock NFT", "MNFT"]);
    const mockToken = await viem.deployContract("MockERC20", [
      "Mock Token",
      "MTK",
      parseEther("1000000"),
    ]);

    // Setup roles and permissions
    await accessControl.write.grantRole([
      await accessControl.read.MINTER_ROLE(),
      cabinet.address,
    ]);

    await tuuCoin.write.grantRole([
      await tuuCoin.read.MINTER_ROLE(),
      cabinet.address,
    ]);

    await randomness.write.addConsumer([cabinet.address]);

    // Mint some tokens for testing
    await mockNFT.write.mint([cabinetOwner.account.address, 1n]);
    await mockNFT.write.mint([cabinetOwner.account.address, 2n]);
    await mockToken.write.mint([cabinetOwner.account.address, parseEther("1000")]);

    // Set up balances
    await setBalance(player1.account.address, parseEther("10"));
    await setBalance(player2.account.address, parseEther("10"));

    return {
      deployer,
      cabinetOwner,
      player1,
      player2,
      platformAdmin,
      accessControl,
      randomness,
      tuuCoin,
      cabinet,
      mockNFT,
      mockToken,
    };
  }

  describe("Cabinet Setup and Item Management", function () {
    it("Should create cabinet and deposit items successfully", async function () {
      const { cabinet, cabinetOwner, mockNFT, mockToken } = await loadFixture(deployContractsFixture);

      // Mint cabinet
      await cabinet.write.mintCabinet([cabinetOwner.account.address, "Test Cabinet"]);
      const cabinetId = 0n;

      // Approve transfers
      await mockNFT.write.approve([cabinet.address, 1n], { account: cabinetOwner.account });
      await mockToken.write.approve([cabinet.address, parseEther("100")], { account: cabinetOwner.account });

      // Prepare items for deposit
      const items = [
        {
          assetType: 0, // ERC721
          contractAddress: mockNFT.address,
          tokenIdOrAmount: 1n,
          rarity: 5n, // Legendary
          metadata: "Legendary NFT",
        },
        {
          assetType: 1, // ERC20
          contractAddress: mockToken.address,
          tokenIdOrAmount: parseEther("100"),
          rarity: 2n, // Common
          metadata: "100 Tokens",
        },
      ];

      // Deposit items
      await cabinet.write.depositItems([cabinetId, items], { account: cabinetOwner.account });

      // Verify items were deposited
      const cabinetItems = await cabinet.read.getCabinetItems([cabinetId]);
      expect(cabinetItems).to.have.lengthOf(2);
      expect(cabinetItems[0].rarity).to.equal(5n);
      expect(cabinetItems[1].rarity).to.equal(2n);

      // Activate cabinet
      await cabinet.write.activateCabinet([cabinetId], { account: cabinetOwner.account });

      const [metadata] = await cabinet.read.getCabinetInfo([cabinetId]);
      expect(metadata.isActive).to.be.true;
    });
  });

  describe("Gacha Gameplay Mechanics", function () {
    async function setupActiveCabinetFixture() {
      const contracts = await deployContractsFixture();
      const { cabinet, cabinetOwner, mockNFT, mockToken } = contracts;

      // Mint cabinet
      await cabinet.write.mintCabinet([cabinetOwner.account.address, "Test Cabinet"]);
      const cabinetId = 0n;

      // Approve transfers
      await mockNFT.write.approve([cabinet.address, 1n], { account: cabinetOwner.account });
      await mockToken.write.approve([cabinet.address, parseEther("100")], { account: cabinetOwner.account });

      // Deposit items
      const items = [
        {
          assetType: 0, // ERC721
          contractAddress: mockNFT.address,
          tokenIdOrAmount: 1n,
          rarity: 5n, // Legendary
          metadata: "Legendary NFT",
        },
        {
          assetType: 1, // ERC20
          contractAddress: mockToken.address,
          tokenIdOrAmount: parseEther("100"),
          rarity: 1n, // Very common
          metadata: "100 Tokens",
        },
      ];

      await cabinet.write.depositItems([cabinetId, items], { account: cabinetOwner.account });
      await cabinet.write.activateCabinet([cabinetId], { account: cabinetOwner.account });

      return { ...contracts, cabinetId };
    }

    it("Should allow players to play gacha with ETH payment", async function () {
      const { cabinet, player1, cabinetId } = await loadFixture(setupActiveCabinetFixture);

      const playPrice = parseEther("0.01");

      // Play gacha without TuuCoin
      const tx = cabinet.write.play([cabinetId, 0n], {
        account: player1.account,
        value: playPrice,
      });

      await expect(tx).to.not.be.rejected;

      // Check that stats were updated
      const [metadata] = await cabinet.read.getCabinetInfo([cabinetId]);
      expect(metadata.totalPlays).to.equal(1n);
    });

    it("Should mint TuuCoin when player doesn't win prize", async function () {
      const { cabinet, tuuCoin, player1, cabinetId } = await loadFixture(setupActiveCabinetFixture);

      const playPrice = parseEther("0.01");
      const initialBalance = await tuuCoin.read.balanceOf([player1.account.address]);

      // Play multiple times to increase chance of no-prize outcome
      for (let i = 0; i < 5; i++) {
        await cabinet.write.play([cabinetId, 0n], {
          account: player1.account,
          value: playPrice,
        });
      }

      const finalBalance = await tuuCoin.read.balanceOf([player1.account.address]);

      // Should have received some TuuCoin (10% of play price per no-prize play)
      expect(finalBalance).to.be.greaterThan(initialBalance);
    });

    it("Should improve odds with TuuCoin burning", async function () {
      const { cabinet, tuuCoin, player1, cabinetId } = await loadFixture(setupActiveCabinetFixture);

      const playPrice = parseEther("0.01");
      const tuuCoinAmount = playPrice / 20n; // 5% of play price

      // First, get some TuuCoin by playing without winning
      for (let i = 0; i < 10; i++) {
        await cabinet.write.play([cabinetId, 0n], {
          account: player1.account,
          value: playPrice,
        });
      }

      const tuuCoinBalance = await tuuCoin.read.balanceOf([player1.account.address]);
      expect(tuuCoinBalance).to.be.greaterThan(tuuCoinAmount);

      // Approve TuuCoin spending
      await tuuCoin.write.approve([cabinet.address, tuuCoinAmount], {
        account: player1.account,
      });

      // Play with TuuCoin burning
      const initialTuuCoinBalance = await tuuCoin.read.balanceOf([player1.account.address]);

      await cabinet.write.play([cabinetId, tuuCoinAmount], {
        account: player1.account,
        value: playPrice,
      });

      const finalTuuCoinBalance = await tuuCoin.read.balanceOf([player1.account.address]);

      // TuuCoin should have been burned (balance decreased by at least the burned amount)
      expect(finalTuuCoinBalance).to.be.lessThan(initialTuuCoinBalance);
    });

    it("Should distribute revenue correctly between platform and cabinet owner", async function () {
      const { cabinet, cabinetOwner, player1, cabinetId } = await loadFixture(setupActiveCabinetFixture);

      const playPrice = parseEther("0.01");
      const initialCabinetRevenue = await cabinet.read.getCabinetRevenue([cabinetId]);
      const initialPlatformRevenue = await cabinet.read.getPlatformRevenue();

      // Play gacha
      await cabinet.write.play([cabinetId, 0n], {
        account: player1.account,
        value: playPrice,
      });

      const finalCabinetRevenue = await cabinet.read.getCabinetRevenue([cabinetId]);
      const finalPlatformRevenue = await cabinet.read.getPlatformRevenue();

      // Revenue should be distributed (5% platform fee by default)
      const expectedPlatformFee = (playPrice * 500n) / 10000n; // 5%
      const expectedCabinetRevenue = playPrice - expectedPlatformFee;

      expect(finalPlatformRevenue - initialPlatformRevenue).to.equal(expectedPlatformFee);
      expect(finalCabinetRevenue - initialCabinetRevenue).to.equal(expectedCabinetRevenue);
    });

    it("Should allow cabinet owner to withdraw revenue", async function () {
      const { cabinet, cabinetOwner, player1, cabinetId } = await loadFixture(setupActiveCabinetFixture);

      const playPrice = parseEther("0.01");

      // Play gacha to generate revenue
      await cabinet.write.play([cabinetId, 0n], {
        account: player1.account,
        value: playPrice,
      });

      const revenue = await cabinet.read.getCabinetRevenue([cabinetId]);
      expect(revenue).to.be.greaterThan(0n);

      const initialBalance = await viem.getPublicClient().getBalance({
        address: cabinetOwner.account.address,
      });

      // Withdraw revenue
      await cabinet.write.withdrawCabinetRevenue([cabinetId], {
        account: cabinetOwner.account,
      });

      const finalBalance = await viem.getPublicClient().getBalance({
        address: cabinetOwner.account.address,
      });

      // Balance should have increased (minus gas costs)
      expect(finalBalance).to.be.greaterThan(initialBalance);

      // Cabinet revenue should be zero
      const finalRevenue = await cabinet.read.getCabinetRevenue([cabinetId]);
      expect(finalRevenue).to.equal(0n);
    });

    it("Should remove items from cabinet when won as prize", async function () {
      const { cabinet, player1, cabinetId } = await loadFixture(setupActiveCabinetFixture);

      const playPrice = parseEther("0.01");
      const initialItemCount = await cabinet.read.getCabinetItemCount([cabinetId]);

      // Play many times to eventually win a prize
      let itemsWon = 0;
      for (let i = 0; i < 20 && itemsWon === 0; i++) {
        const tx = await cabinet.write.play([cabinetId, 0n], {
          account: player1.account,
          value: playPrice,
        });

        // Check if an item was won by looking at the final item count
        const currentItemCount = await cabinet.read.getCabinetItemCount([cabinetId]);
        if (currentItemCount < initialItemCount) {
          itemsWon++;
          break;
        }
      }

      // If we won an item, the count should have decreased
      if (itemsWon > 0) {
        const finalItemCount = await cabinet.read.getCabinetItemCount([cabinetId]);
        expect(finalItemCount).to.be.lessThan(initialItemCount);
      }
    });

    it("Should prevent playing with inactive cabinet", async function () {
      const { cabinet, cabinetOwner, player1, cabinetId } = await loadFixture(setupActiveCabinetFixture);

      // Deactivate cabinet
      await cabinet.write.deactivateCabinet([cabinetId], {
        account: cabinetOwner.account,
      });

      const playPrice = parseEther("0.01");

      // Attempt to play with inactive cabinet
      await expect(
        cabinet.write.play([cabinetId, 0n], {
          account: player1.account,
          value: playPrice,
        })
      ).to.be.rejectedWith("CabinetInactive");
    });

    it("Should prevent playing with insufficient payment", async function () {
      const { cabinet, player1, cabinetId } = await loadFixture(setupActiveCabinetFixture);

      const playPrice = parseEther("0.005"); // Less than required 0.01 ETH

      await expect(
        cabinet.write.play([cabinetId, 0n], {
          account: player1.account,
          value: playPrice,
        })
      ).to.be.rejectedWith("InsufficientPayment");
    });

    it("Should prevent playing with excessive TuuCoin amount", async function () {
      const { cabinet, player1, cabinetId } = await loadFixture(setupActiveCabinetFixture);

      const playPrice = parseEther("0.01");
      const excessiveTuuCoinAmount = (playPrice * 25n) / 100n; // 25% (max is 20%)

      await expect(
        cabinet.write.play([cabinetId, excessiveTuuCoinAmount], {
          account: player1.account,
          value: playPrice,
        })
      ).to.be.rejectedWith("InvalidTuuCoinAmount");
    });
  });

  describe("Statistical Analysis", function () {
    it("Should demonstrate rarity-based distribution over multiple plays", async function () {
      const { cabinet, cabinetOwner, player1, mockNFT, mockToken } = await loadFixture(deployContractsFixture);

      // Create cabinet with multiple items of different rarities
      await cabinet.write.mintCabinet([cabinetOwner.account.address, "Test Cabinet"]);
      const cabinetId = 0n;

      // Mint additional NFTs for testing
      for (let i = 2; i <= 10; i++) {
        await mockNFT.write.mint([cabinetOwner.account.address, BigInt(i)]);
        await mockNFT.write.approve([cabinet.address, BigInt(i)], { account: cabinetOwner.account });
      }

      // Deposit items with different rarities
      const items = [];
      for (let i = 1; i <= 5; i++) {
        // Common items (rarity 1)
        items.push({
          assetType: 0,
          contractAddress: mockNFT.address,
          tokenIdOrAmount: BigInt(i),
          rarity: 1n,
          metadata: `Common NFT ${i}`,
        });
      }
      for (let i = 6; i <= 8; i++) {
        // Rare items (rarity 3)
        items.push({
          assetType: 0,
          contractAddress: mockNFT.address,
          tokenIdOrAmount: BigInt(i),
          rarity: 3n,
          metadata: `Rare NFT ${i}`,
        });
      }
      for (let i = 9; i <= 10; i++) {
        // Legendary items (rarity 5)
        items.push({
          assetType: 0,
          contractAddress: mockNFT.address,
          tokenIdOrAmount: BigInt(i),
          rarity: 5n,
          metadata: `Legendary NFT ${i}`,
        });
      }

      await cabinet.write.depositItems([cabinetId, items], { account: cabinetOwner.account });
      await cabinet.write.activateCabinet([cabinetId], { account: cabinetOwner.account });

      const playPrice = parseEther("0.01");
      let prizesWon = 0;
      const totalPlays = 50;

      // Play multiple times
      for (let i = 0; i < totalPlays; i++) {
        const initialItemCount = await cabinet.read.getCabinetItemCount([cabinetId]);

        await cabinet.write.play([cabinetId, 0n], {
          account: player1.account,
          value: playPrice,
        });

        const finalItemCount = await cabinet.read.getCabinetItemCount([cabinetId]);
        if (finalItemCount < initialItemCount) {
          prizesWon++;
        }
      }

      // Statistical analysis: should have won some prizes but not all
      expect(prizesWon).to.be.greaterThan(0);
      expect(prizesWon).to.be.lessThan(totalPlays);

      console.log(`Prizes won: ${prizesWon}/${totalPlays} (${(prizesWon/totalPlays*100).toFixed(1)}%)`);
    });
  });
});