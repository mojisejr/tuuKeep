import { expect } from "chai";
import { ethers } from "hardhat";
import { TuuCoin, TuuKeepAccessControl } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("TuuCoin", function () {
  let tuuCoin: TuuCoin;
  let accessControl: TuuKeepAccessControl;
  let owner: SignerWithAddress;
  let admin: SignerWithAddress;
  let minter: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;

  const INITIAL_SUPPLY = 0;
  const MAX_SUPPLY = ethers.parseEther("1000000000"); // 1 billion tokens
  const MINT_AMOUNT = ethers.parseEther("1000");
  const BURN_AMOUNT = ethers.parseEther("500");

  beforeEach(async function () {
    [owner, admin, minter, user1, user2] = await ethers.getSigners();

    // Deploy TuuKeepAccessControl first
    const TuuKeepAccessControlFactory = await ethers.getContractFactory("TuuKeepAccessControl");
    accessControl = await TuuKeepAccessControlFactory.deploy();
    await accessControl.waitForDeployment();

    // Deploy TuuCoin with access control integration
    const TuuCoinFactory = await ethers.getContractFactory("TuuCoin");
    tuuCoin = await TuuCoinFactory.deploy(
      await accessControl.getAddress(),
      admin.address
    );
    await tuuCoin.waitForDeployment();

    // Grant minter role to designated minter
    const MINTER_ROLE = await tuuCoin.MINTER_ROLE();
    await tuuCoin.connect(admin).grantRole(MINTER_ROLE, minter.address);
  });

  describe("Deployment", function () {
    it("Should deploy successfully with correct parameters", async function () {
      expect(await tuuCoin.name()).to.equal("TuuCoin");
      expect(await tuuCoin.symbol()).to.equal("TUU");
      expect(await tuuCoin.decimals()).to.equal(18);
      expect(await tuuCoin.totalSupply()).to.equal(INITIAL_SUPPLY);
      expect(await tuuCoin.MAX_SUPPLY()).to.equal(MAX_SUPPLY);
    });

    it("Should set access control contract correctly", async function () {
      expect(await tuuCoin.accessControl()).to.equal(await accessControl.getAddress());
    });

    it("Should grant initial roles to admin", async function () {
      const DEFAULT_ADMIN_ROLE = await tuuCoin.DEFAULT_ADMIN_ROLE();
      const PLATFORM_ADMIN_ROLE = await tuuCoin.PLATFORM_ADMIN_ROLE();
      const MINTER_ROLE = await tuuCoin.MINTER_ROLE();

      expect(await tuuCoin.hasRole(DEFAULT_ADMIN_ROLE, admin.address)).to.be.true;
      expect(await tuuCoin.hasRole(PLATFORM_ADMIN_ROLE, admin.address)).to.be.true;
      expect(await tuuCoin.hasRole(MINTER_ROLE, admin.address)).to.be.true;
    });

    it("Should reject deployment with zero address parameters", async function () {
      const TuuCoinFactory = await ethers.getContractFactory("TuuCoin");

      await expect(
        TuuCoinFactory.deploy(ethers.ZeroAddress, admin.address)
      ).to.be.revertedWith("TuuCoin: invalid access control address");

      await expect(
        TuuCoinFactory.deploy(await accessControl.getAddress(), ethers.ZeroAddress)
      ).to.be.revertedWith("TuuCoin: invalid admin address");
    });
  });

  describe("Minting", function () {
    it("Should allow minter to mint tokens", async function () {
      await expect(tuuCoin.connect(minter).mint(user1.address, MINT_AMOUNT))
        .to.emit(tuuCoin, "TokensMinted")
        .withArgs(user1.address, MINT_AMOUNT, minter.address);

      expect(await tuuCoin.balanceOf(user1.address)).to.equal(MINT_AMOUNT);
      expect(await tuuCoin.totalMinted()).to.equal(MINT_AMOUNT);
      expect(await tuuCoin.totalSupply()).to.equal(MINT_AMOUNT);
    });

    it("Should reject minting by non-minter", async function () {
      const MINTER_ROLE = await tuuCoin.MINTER_ROLE();

      await expect(
        tuuCoin.connect(user1).mint(user1.address, MINT_AMOUNT)
      ).to.be.revertedWith(
        `AccessControl: account ${user1.address.toLowerCase()} is missing role ${MINTER_ROLE}`
      );
    });

    it("Should reject minting to zero address", async function () {
      await expect(
        tuuCoin.connect(minter).mint(ethers.ZeroAddress, MINT_AMOUNT)
      ).to.be.revertedWith("TuuCoin: cannot mint to zero address");
    });

    it("Should reject minting zero amount", async function () {
      await expect(
        tuuCoin.connect(minter).mint(user1.address, 0)
      ).to.be.revertedWith("TuuCoin: amount must be greater than zero");
    });

    it("Should enforce max supply limit", async function () {
      const largeAmount = MAX_SUPPLY + ethers.parseEther("1");

      await expect(
        tuuCoin.connect(minter).mint(user1.address, largeAmount)
      ).to.be.revertedWith("TuuCoin: would exceed max supply");
    });

    it("Should track total minted correctly across multiple mints", async function () {
      await tuuCoin.connect(minter).mint(user1.address, MINT_AMOUNT);
      await tuuCoin.connect(minter).mint(user2.address, MINT_AMOUNT);

      expect(await tuuCoin.totalMinted()).to.equal(MINT_AMOUNT * 2n);
      expect(await tuuCoin.totalSupply()).to.equal(MINT_AMOUNT * 2n);
    });
  });

  describe("Batch Minting", function () {
    it("Should batch mint to multiple recipients", async function () {
      const recipients = [user1.address, user2.address];
      const amounts = [MINT_AMOUNT, MINT_AMOUNT / 2n];

      await tuuCoin.connect(minter).batchMint(recipients, amounts);

      expect(await tuuCoin.balanceOf(user1.address)).to.equal(MINT_AMOUNT);
      expect(await tuuCoin.balanceOf(user2.address)).to.equal(MINT_AMOUNT / 2n);
      expect(await tuuCoin.totalMinted()).to.equal(MINT_AMOUNT + MINT_AMOUNT / 2n);
    });

    it("Should emit TokensMinted events for each recipient", async function () {
      const recipients = [user1.address, user2.address];
      const amounts = [MINT_AMOUNT, MINT_AMOUNT / 2n];

      const tx = await tuuCoin.connect(minter).batchMint(recipients, amounts);
      const receipt = await tx.wait();

      // Should have 2 TokensMinted events
      const events = receipt?.logs.filter(log => {
        try {
          const parsed = tuuCoin.interface.parseLog(log);
          return parsed?.name === "TokensMinted";
        } catch {
          return false;
        }
      });

      expect(events).to.have.length(2);
    });

    it("Should reject batch mint with mismatched array lengths", async function () {
      const recipients = [user1.address, user2.address];
      const amounts = [MINT_AMOUNT]; // Length mismatch

      await expect(
        tuuCoin.connect(minter).batchMint(recipients, amounts)
      ).to.be.revertedWith("TuuCoin: arrays length mismatch");
    });

    it("Should reject batch mint with empty arrays", async function () {
      await expect(
        tuuCoin.connect(minter).batchMint([], [])
      ).to.be.revertedWith("TuuCoin: empty arrays");
    });

    it("Should reject batch mint with zero address recipient", async function () {
      const recipients = [user1.address, ethers.ZeroAddress];
      const amounts = [MINT_AMOUNT, MINT_AMOUNT];

      await expect(
        tuuCoin.connect(minter).batchMint(recipients, amounts)
      ).to.be.revertedWith("TuuCoin: cannot mint to zero address");
    });

    it("Should reject batch mint with zero amount", async function () {
      const recipients = [user1.address, user2.address];
      const amounts = [MINT_AMOUNT, 0];

      await expect(
        tuuCoin.connect(minter).batchMint(recipients, amounts)
      ).to.be.revertedWith("TuuCoin: amount must be greater than zero");
    });

    it("Should enforce max supply in batch operations", async function () {
      const recipients = [user1.address, user2.address];
      const amounts = [MAX_SUPPLY / 2n + 1n, MAX_SUPPLY / 2n + 1n];

      await expect(
        tuuCoin.connect(minter).batchMint(recipients, amounts)
      ).to.be.revertedWith("TuuCoin: would exceed max supply");
    });
  });

  describe("Burning", function () {
    beforeEach(async function () {
      // Mint tokens to user1 for burning tests
      await tuuCoin.connect(minter).mint(user1.address, MINT_AMOUNT);
    });

    it("Should allow users to burn tokens for odds improvement", async function () {
      await expect(tuuCoin.connect(user1).burnForOdds(BURN_AMOUNT))
        .to.emit(tuuCoin, "TokensBurnedForOdds")
        .withArgs(user1.address, BURN_AMOUNT, BURN_AMOUNT);

      expect(await tuuCoin.balanceOf(user1.address)).to.equal(MINT_AMOUNT - BURN_AMOUNT);
      expect(await tuuCoin.totalBurned()).to.equal(BURN_AMOUNT);
      expect(await tuuCoin.userBurnedAmount(user1.address)).to.equal(BURN_AMOUNT);
      expect(await tuuCoin.userBurnCount(user1.address)).to.equal(1);
    });

    it("Should track burn statistics correctly across multiple burns", async function () {
      const firstBurn = BURN_AMOUNT / 2n;
      const secondBurn = BURN_AMOUNT / 2n;

      await tuuCoin.connect(user1).burnForOdds(firstBurn);
      await tuuCoin.connect(user1).burnForOdds(secondBurn);

      expect(await tuuCoin.userBurnedAmount(user1.address)).to.equal(BURN_AMOUNT);
      expect(await tuuCoin.userBurnCount(user1.address)).to.equal(2);
      expect(await tuuCoin.totalBurned()).to.equal(BURN_AMOUNT);
    });

    it("Should reject burning zero amount", async function () {
      await expect(
        tuuCoin.connect(user1).burnForOdds(0)
      ).to.be.revertedWith("TuuCoin: amount must be greater than zero");
    });

    it("Should reject burning more than balance", async function () {
      const excessiveAmount = MINT_AMOUNT + ethers.parseEther("1");

      await expect(
        tuuCoin.connect(user1).burnForOdds(excessiveAmount)
      ).to.be.revertedWith("TuuCoin: insufficient balance");
    });

    it("Should reduce total supply when burning", async function () {
      const initialSupply = await tuuCoin.totalSupply();

      await tuuCoin.connect(user1).burnForOdds(BURN_AMOUNT);

      expect(await tuuCoin.totalSupply()).to.equal(initialSupply - BURN_AMOUNT);
    });
  });

  describe("Odds Calculation", function () {
    beforeEach(async function () {
      // Mint tokens to user1 for odds tests
      await tuuCoin.connect(minter).mint(user1.address, ethers.parseEther("10000"));
    });

    it("Should return zero improvement for users who haven't burned", async function () {
      expect(await tuuCoin.calculateOddsImprovement(user1.address)).to.equal(0);
      expect(await tuuCoin.calculateOddsImprovement(user2.address)).to.equal(0);
    });

    it("Should calculate odds improvement based on burned amount", async function () {
      const burnAmount = ethers.parseEther("2000"); // 2000 tokens
      await tuuCoin.connect(user1).burnForOdds(burnAmount);

      // Should get 2 basis points improvement (2000 / 1000 = 2)
      expect(await tuuCoin.calculateOddsImprovement(user1.address)).to.equal(2);
    });

    it("Should cap odds improvement at 500 basis points", async function () {
      const largeBurnAmount = ethers.parseEther("1000000"); // 1M tokens
      await tuuCoin.connect(minter).mint(user1.address, largeBurnAmount);
      await tuuCoin.connect(user1).burnForOdds(largeBurnAmount);

      // Should be capped at 500 basis points (5%)
      expect(await tuuCoin.calculateOddsImprovement(user1.address)).to.equal(500);
    });

    it("Should handle partial token amounts correctly", async function () {
      const burnAmount = ethers.parseEther("1500"); // 1500 tokens
      await tuuCoin.connect(user1).burnForOdds(burnAmount);

      // Should get 1 basis point improvement (1500 / 1000 = 1.5, floored to 1)
      expect(await tuuCoin.calculateOddsImprovement(user1.address)).to.equal(1);
    });
  });

  describe("Burn Statistics", function () {
    beforeEach(async function () {
      await tuuCoin.connect(minter).mint(user1.address, MINT_AMOUNT);
      await tuuCoin.connect(minter).mint(user2.address, MINT_AMOUNT);
    });

    it("Should return correct burn statistics", async function () {
      await tuuCoin.connect(user1).burnForOdds(BURN_AMOUNT);

      const [burnedAmount, burnCount] = await tuuCoin.getUserBurnStats(user1.address);
      expect(burnedAmount).to.equal(BURN_AMOUNT);
      expect(burnCount).to.equal(1);
    });

    it("Should return zero statistics for users who haven't burned", async function () {
      const [burnedAmount, burnCount] = await tuuCoin.getUserBurnStats(user2.address);
      expect(burnedAmount).to.equal(0);
      expect(burnCount).to.equal(0);
    });

    it("Should track independent burn statistics for different users", async function () {
      await tuuCoin.connect(user1).burnForOdds(BURN_AMOUNT);
      await tuuCoin.connect(user2).burnForOdds(BURN_AMOUNT / 2n);

      const [user1Burned, user1Count] = await tuuCoin.getUserBurnStats(user1.address);
      const [user2Burned, user2Count] = await tuuCoin.getUserBurnStats(user2.address);

      expect(user1Burned).to.equal(BURN_AMOUNT);
      expect(user1Count).to.equal(1);
      expect(user2Burned).to.equal(BURN_AMOUNT / 2n);
      expect(user2Count).to.equal(1);
    });
  });

  describe("Supply Statistics", function () {
    it("Should return correct supply statistics", async function () {
      await tuuCoin.connect(minter).mint(user1.address, MINT_AMOUNT);
      await tuuCoin.connect(user1).burnForOdds(BURN_AMOUNT);

      const [currentSupply, mintedSupply, burnedSupply, maxSupply] =
        await tuuCoin.getSupplyStats();

      expect(currentSupply).to.equal(MINT_AMOUNT - BURN_AMOUNT);
      expect(mintedSupply).to.equal(MINT_AMOUNT);
      expect(burnedSupply).to.equal(BURN_AMOUNT);
      expect(maxSupply).to.equal(MAX_SUPPLY);
    });

    it("Should track statistics correctly across multiple operations", async function () {
      // Multiple mints and burns
      await tuuCoin.connect(minter).mint(user1.address, MINT_AMOUNT);
      await tuuCoin.connect(minter).mint(user2.address, MINT_AMOUNT);
      await tuuCoin.connect(user1).burnForOdds(BURN_AMOUNT);

      const [currentSupply, mintedSupply, burnedSupply, maxSupply] =
        await tuuCoin.getSupplyStats();

      expect(currentSupply).to.equal(MINT_AMOUNT * 2n - BURN_AMOUNT);
      expect(mintedSupply).to.equal(MINT_AMOUNT * 2n);
      expect(burnedSupply).to.equal(BURN_AMOUNT);
      expect(maxSupply).to.equal(MAX_SUPPLY);
    });
  });

  describe("Access Control Integration", function () {
    it("Should allow updating access control by platform admin", async function () {
      // Deploy new access control contract
      const TuuKeepAccessControlFactory = await ethers.getContractFactory("TuuKeepAccessControl");
      const newAccessControl = await TuuKeepAccessControlFactory.deploy();
      await newAccessControl.waitForDeployment();

      await expect(
        tuuCoin.connect(admin).updateAccessControl(await newAccessControl.getAddress())
      ).to.emit(tuuCoin, "AccessControlUpdated")
        .withArgs(await newAccessControl.getAddress(), admin.address);
    });

    it("Should reject updating access control by non-admin", async function () {
      const TuuKeepAccessControlFactory = await ethers.getContractFactory("TuuKeepAccessControl");
      const newAccessControl = await TuuKeepAccessControlFactory.deploy();
      await newAccessControl.waitForDeployment();

      const PLATFORM_ADMIN_ROLE = await tuuCoin.PLATFORM_ADMIN_ROLE();

      await expect(
        tuuCoin.connect(user1).updateAccessControl(await newAccessControl.getAddress())
      ).to.be.revertedWith(
        `AccessControl: account ${user1.address.toLowerCase()} is missing role ${PLATFORM_ADMIN_ROLE}`
      );
    });

    it("Should reject updating to zero address", async function () {
      await expect(
        tuuCoin.connect(admin).updateAccessControl(ethers.ZeroAddress)
      ).to.be.revertedWith("TuuCoin: invalid access control address");
    });

    it("Should reject updating to same address", async function () {
      await expect(
        tuuCoin.connect(admin).updateAccessControl(await accessControl.getAddress())
      ).to.be.revertedWith("TuuCoin: same access control address");
    });
  });

  describe("Standard ERC20 Functionality", function () {
    beforeEach(async function () {
      await tuuCoin.connect(minter).mint(user1.address, MINT_AMOUNT);
    });

    it("Should support transfer functionality", async function () {
      const transferAmount = MINT_AMOUNT / 2n;

      await tuuCoin.connect(user1).transfer(user2.address, transferAmount);

      expect(await tuuCoin.balanceOf(user1.address)).to.equal(MINT_AMOUNT - transferAmount);
      expect(await tuuCoin.balanceOf(user2.address)).to.equal(transferAmount);
    });

    it("Should support approve and transferFrom functionality", async function () {
      const transferAmount = MINT_AMOUNT / 2n;

      await tuuCoin.connect(user1).approve(user2.address, transferAmount);
      await tuuCoin.connect(user2).transferFrom(user1.address, user2.address, transferAmount);

      expect(await tuuCoin.balanceOf(user1.address)).to.equal(MINT_AMOUNT - transferAmount);
      expect(await tuuCoin.balanceOf(user2.address)).to.equal(transferAmount);
    });

    it("Should support ERC20Burnable burn functionality", async function () {
      const burnAmount = MINT_AMOUNT / 2n;

      await tuuCoin.connect(user1).burn(burnAmount);

      expect(await tuuCoin.balanceOf(user1.address)).to.equal(MINT_AMOUNT - burnAmount);
      expect(await tuuCoin.totalSupply()).to.equal(MINT_AMOUNT - burnAmount);
    });
  });

  describe("Interface Support", function () {
    it("Should support AccessControl interface", async function () {
      // ERC165 interface ID for AccessControl
      const accessControlInterfaceId = "0x7965db0b";
      expect(await tuuCoin.supportsInterface(accessControlInterfaceId)).to.be.true;
    });

    it("Should support ERC20 interface", async function () {
      // Standard transfer should work (covered in other tests)
      await tuuCoin.connect(minter).mint(user1.address, MINT_AMOUNT);
      await expect(tuuCoin.connect(user1).transfer(user2.address, MINT_AMOUNT / 2n))
        .to.not.be.reverted;
    });
  });

  describe("Edge Cases and Security", function () {
    it("Should handle zero balance burns gracefully", async function () {
      await expect(
        tuuCoin.connect(user1).burnForOdds(1)
      ).to.be.revertedWith("TuuCoin: insufficient balance");
    });

    it("Should prevent integer overflow in batch minting", async function () {
      const maxUint256 = 2n ** 256n - 1n;
      const recipients = [user1.address, user2.address];
      const amounts = [maxUint256 / 2n + 1n, maxUint256 / 2n + 1n];

      await expect(
        tuuCoin.connect(minter).batchMint(recipients, amounts)
      ).to.be.revertedWith("TuuCoin: would exceed max supply");
    });

    it("Should maintain consistency between totalSupply and individual balances", async function () {
      await tuuCoin.connect(minter).mint(user1.address, MINT_AMOUNT);
      await tuuCoin.connect(minter).mint(user2.address, MINT_AMOUNT);

      const totalSupply = await tuuCoin.totalSupply();
      const balance1 = await tuuCoin.balanceOf(user1.address);
      const balance2 = await tuuCoin.balanceOf(user2.address);

      expect(totalSupply).to.equal(balance1 + balance2);
    });
  });
});