import { expect } from "chai";
import { describe, it, beforeEach } from "node:test";
import { network } from "hardhat";
import { getAddress, parseEther } from "viem";

describe("TuuCoin - Viem Tests", function () {
  let tuuCoin: any;
  let accessControl: any;
  let accounts: any[];
  let publicClient: any;
  let walletClient: any;

  const MAX_SUPPLY = parseEther("1000000000"); // 1 billion tokens

  beforeEach(async function () {
    // Connect to network and get viem clients
    const { viem } = await network.connect();
    accounts = await viem.getWalletClients();
    publicClient = await viem.getPublicClient();
    walletClient = accounts[0];

    // Deploy TuuKeepAccessControl first
    accessControl = await viem.deployContract("TuuKeepAccessControl");

    // Deploy TuuCoin contract with proper parameters
    tuuCoin = await viem.deployContract("TuuCoin", [
      accessControl.address, // accessControl address
      accounts[0].account.address // initialAdmin address
    ]);
  });

  describe("Deployment", function () {
    it("Should deploy with correct initial parameters", async function () {
      expect(await tuuCoin.read.name()).to.equal("TuuCoin");
      expect(await tuuCoin.read.symbol()).to.equal("TUU");
      expect(await tuuCoin.read.totalSupply()).to.equal(0n); // Initial supply is 0
    });

    it("Should set the correct max supply", async function () {
      const stats = await tuuCoin.read.getSupplyStats();
      expect(stats[3]).to.equal(MAX_SUPPLY); // maxSupply
    });
  });

  describe("Minting", function () {
    it("Should mint tokens successfully", async function () {
      const MINT_AMOUNT = parseEther("500");
      const recipient = accounts[2].account.address;

      // accounts[0] already has MINTER_ROLE from constructor
      await tuuCoin.write.mint([recipient, MINT_AMOUNT], {
        account: accounts[0].account
      });

      expect(await tuuCoin.read.balanceOf([recipient])).to.equal(MINT_AMOUNT);
    });

    it("Should prevent minting beyond max supply", async function () {
       const excessiveAmount = MAX_SUPPLY + 1n;
       
       try {
         await tuuCoin.write.mint([accounts[2].account.address, excessiveAmount], {
           account: accounts[0].account
         });
         expect.fail("Should have thrown an error");
       } catch (error: any) {
         expect(error.message).to.include("revert");
       }
     });
  });

  describe("Burning", function () {
    it("Should burn tokens successfully", async function () {
      const MINT_AMOUNT = parseEther("1000");
      const BURN_AMOUNT = parseEther("300");
      const holder = accounts[1].account.address;

      // First mint tokens
      await tuuCoin.write.mint([holder, MINT_AMOUNT], {
        account: accounts[0].account
      });

      // Then burn tokens
      await tuuCoin.write.burn([BURN_AMOUNT], {
        account: accounts[1].account
      });

      const finalBalance = await tuuCoin.read.balanceOf([holder]);
      expect(finalBalance).to.equal(MINT_AMOUNT - BURN_AMOUNT);
    });

    it("Should track burned amounts", async function () {
        const MINT_AMOUNT = parseEther("1000");
        const BURN_AMOUNT = parseEther("200");
        const holder = accounts[1].account.address;

        // Mint and burn for odds improvement
        await tuuCoin.write.mint([holder, MINT_AMOUNT], {
          account: accounts[0].account
        });
        
        await tuuCoin.write.burnForOdds([BURN_AMOUNT], {
          account: accounts[1].account
        });

        const burnStats = await tuuCoin.read.getUserBurnStats([holder]);
        expect(burnStats[0]).to.equal(BURN_AMOUNT); // totalBurned
      });
  });

  describe("Cabinet Integration", function () {
     it("Should register cabinet successfully", async function () {
        const cabinetId = 1n;
        const owner = accounts[2].account.address;

        // accounts[0] already has CABINET_OPERATOR_ROLE from constructor
        const hash = await tuuCoin.write.registerCabinet([cabinetId, owner], {
          account: accounts[0].account
        });

        const receipt = await publicClient.waitForTransactionReceipt({ hash });
        expect(Number(receipt.gasUsed)).to.be.lessThan(150000); // Increased gas limit
        
        const cabinetInfo = await tuuCoin.read.getCabinetInfo([cabinetId]);
         expect(cabinetInfo.owner.toLowerCase()).to.equal(owner.toLowerCase());
         expect(cabinetInfo.isActive).to.equal(true);
      });

     it("Should mint tokens for gacha rewards", async function () {
       const cabinetId = 2n;
       const owner = accounts[2].account.address;
       const player = accounts[3].account.address;
       const rewardAmount = parseEther("100");

       // Register cabinet first
       await tuuCoin.write.registerCabinet([cabinetId, owner], {
         account: accounts[0].account
       });

       // Mint reward tokens
       await tuuCoin.write.mintForGachaReward([player, rewardAmount, cabinetId], {
         account: accounts[0].account
       });

       // Check the actual emission-adjusted amount
       const expectedAmount = await tuuCoin.read.calculateEmissionAmount([cabinetId, rewardAmount]);
       const balance = await tuuCoin.read.balanceOf([player]);
       expect(balance).to.equal(expectedAmount);
     });
   });

  describe("Supply Management", function () {
    it("Should track supply correctly", async function () {
      const MINT_AMOUNT = parseEther("1000");
      
      await tuuCoin.write.mint([accounts[1].account.address, MINT_AMOUNT], {
        account: accounts[0].account
      });

      const currentSupply = await tuuCoin.read.totalSupply();
      const maxSupply = await tuuCoin.read.MAX_SUPPLY();
      
      expect(currentSupply).to.equal(MINT_AMOUNT);
      expect(maxSupply).to.equal(MAX_SUPPLY);
    });
  });

  describe("Access Control", function () {
    it("Should allow role management by admin", async function () {
      const CABINET_OPERATOR_ROLE = await tuuCoin.read.CABINET_OPERATOR_ROLE();
      const testAccount = accounts[5].account.address;

      // Grant role
      await tuuCoin.write.grantRole([CABINET_OPERATOR_ROLE, testAccount], {
        account: accounts[0].account
      });

      expect(await tuuCoin.read.hasRole([CABINET_OPERATOR_ROLE, testAccount])).to.be.true;

      // Revoke role
      await tuuCoin.write.revokeRole([CABINET_OPERATOR_ROLE, testAccount], {
        account: accounts[0].account
      });

      expect(await tuuCoin.read.hasRole([CABINET_OPERATOR_ROLE, testAccount])).to.be.false;
    });
  });

  describe("Gas Optimization", function () {
    it("Should have reasonable gas costs for basic operations", async function () {
      const recipient = accounts[2].account.address;
      const amount = parseEther("100");

      // accounts[0] already has MINTER_ROLE from constructor

      const hash = await tuuCoin.write.mint([recipient, amount], {
        account: accounts[0].account
      });

      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      
      // Gas should be reasonable (less than 100k for mint)
      expect(Number(receipt.gasUsed)).to.be.lessThan(100000);
    });
  });
});