import { expect } from "chai";
import { describe, it, beforeEach } from "node:test";
import { network } from "hardhat";
import { getAddress, parseEther, zeroAddress } from "viem";

describe("TuuKeepCabinet", function () {
  let publicClient: any;
  let deployer: any;
  let user1: any;
  let user2: any;
  let feeRecipient: any;

  let accessControlContract: any;
  let tuuCoinContract: any;
  let cabinetContract: any;

  let accessControlAddress: string;
  let tuuCoinAddress: string;
  let cabinetAddress: string;

  beforeEach(async function () {
    // Connect to network and get viem clients
    const { viem } = await network.connect();
    [deployer, user1, user2, feeRecipient] = await viem.getWalletClients();
    publicClient = await viem.getPublicClient();

    // Deploy TuuKeepAccessControl (no constructor parameters)
    accessControlContract = await viem.deployContract("TuuKeepAccessControl");
    accessControlAddress = getAddress(accessControlContract.address);

    // Deploy TuuCoin
    tuuCoinContract = await viem.deployContract("TuuCoin", [
      accessControlAddress,
      deployer.account.address // initialAdmin
    ]);
    tuuCoinAddress = getAddress(tuuCoinContract.address);

    // Deploy SVGGenerator library first
    const svgGeneratorLib = await viem.deployContract("SVGGenerator");
    const svgGeneratorAddress = getAddress(svgGeneratorLib.address);

    // Deploy TuuKeepCabinet with library linking
    cabinetContract = await viem.deployContract("TuuKeepCabinet", [
      accessControlAddress,
      tuuCoinAddress,
      feeRecipient.account.address
    ], {
      libraries: {
        SVGGenerator: svgGeneratorAddress,
      },
    });
    cabinetAddress = getAddress(cabinetContract.address);
  });

  describe("Deployment", function () {
    it("Should set correct initial parameters", async function () {
      const name = await cabinetContract.read.name();
      const symbol = await cabinetContract.read.symbol();
      const totalCabinets = await cabinetContract.read.totalCabinets();
      const platformFeeRecipient = await cabinetContract.read.platformFeeRecipient();

      expect(name).to.equal("TuuKeep Cabinet");
      expect(symbol).to.equal("CABINET");
      expect(totalCabinets).to.equal(0n);
      expect(getAddress(platformFeeRecipient)).to.equal(getAddress(feeRecipient.account.address));
    });

    it("Should grant correct roles to deployer", async function () {
      const MINTER_ROLE = await cabinetContract.read.MINTER_ROLE();
      const PLATFORM_ADMIN_ROLE = await cabinetContract.read.PLATFORM_ADMIN_ROLE();
      const DEFAULT_ADMIN_ROLE = await cabinetContract.read.DEFAULT_ADMIN_ROLE();

      const hasMinterRole = await cabinetContract.read.hasRole([MINTER_ROLE, deployer.account.address]);
      const hasAdminRole = await cabinetContract.read.hasRole([PLATFORM_ADMIN_ROLE, deployer.account.address]);
      const hasDefaultAdminRole = await cabinetContract.read.hasRole([DEFAULT_ADMIN_ROLE, deployer.account.address]);

      expect(hasMinterRole).to.be.true;
      expect(hasAdminRole).to.be.true;
      expect(hasDefaultAdminRole).to.be.true;
    });

    it("Should revert with invalid constructor parameters", async function () {
      const svgGeneratorLib = await viem.deployContract("SVGGenerator");
      const svgGeneratorAddress = getAddress(svgGeneratorLib.address);

      await expect(
        viem.deployContract("TuuKeepCabinet", [
          zeroAddress,
          tuuCoinAddress,
          feeRecipient.account.address
        ], {
          libraries: {
            SVGGenerator: svgGeneratorAddress,
          },
        })
      ).to.be.rejected;

      await expect(
        viem.deployContract("TuuKeepCabinet", [
          accessControlAddress,
          zeroAddress,
          feeRecipient.account.address
        ], {
          libraries: {
            SVGGenerator: svgGeneratorAddress,
          },
        })
      ).to.be.rejected;

      await expect(
        viem.deployContract("TuuKeepCabinet", [
          accessControlAddress,
          tuuCoinAddress,
          zeroAddress
        ], {
          libraries: {
            SVGGenerator: svgGeneratorAddress,
          },
        })
      ).to.be.rejected;
    });
  });

  describe("Cabinet Minting", function () {
    it("Should mint cabinet with correct parameters", async function () {
      const cabinetName = "Test Cabinet";

      const hash = await cabinetContract.write.mintCabinet([
        user1.account.address,
        cabinetName
      ], { account: deployer.account });

      await publicClient.waitForTransactionReceipt({ hash });

      // Check token was minted
      const totalCabinets = await cabinetContract.read.totalCabinets();
      const owner = await cabinetContract.read.ownerOf([0n]);
      const balance = await cabinetContract.read.balanceOf([user1.account.address]);

      expect(totalCabinets).to.equal(1n);
      expect(getAddress(owner)).to.equal(getAddress(user1.account.address));
      expect(balance).to.equal(1n);

      // Check cabinet metadata
      const [metadata, config] = await cabinetContract.read.getCabinetInfo([0n]);

      expect(metadata.name).to.equal(cabinetName);
      expect(getAddress(metadata.owner)).to.equal(getAddress(user1.account.address));
      expect(metadata.isActive).to.be.false;
      expect(metadata.totalPlays).to.equal(0n);
      expect(metadata.totalRevenue).to.equal(0n);

      // Check default configuration
      expect(config.playPrice).to.equal(parseEther("0.01"));
      expect(config.maxItems).to.equal(10n);
      expect(config.platformFeeRate).to.equal(500n); // 5%
      expect(config.allowsCustomOdds).to.be.true;
    });

    it("Should revert when minting without MINTER_ROLE", async function () {
      await expect(
        cabinetContract.write.mintCabinet([
          user1.account.address,
          "Test Cabinet"
        ], { account: user1.account })
      ).to.be.rejected;
    });

    it("Should revert with invalid cabinet name", async function () {
      await expect(
        cabinetContract.write.mintCabinet([
          user1.account.address,
          ""
        ], { account: deployer.account })
      ).to.be.rejected;
    });

    it("Should revert when minting to zero address", async function () {
      await expect(
        cabinetContract.write.mintCabinet([
          zeroAddress,
          "Test Cabinet"
        ], { account: deployer.account })
      ).to.be.rejected;
    });
  });

  describe("Cabinet Configuration", function () {
    let tokenId: bigint;

    beforeEach(async function () {
      const hash = await cabinetContract.write.mintCabinet([
        user1.account.address,
        "Test Cabinet"
      ], { account: deployer.account });
      await publicClient.waitForTransactionReceipt({ hash });
      tokenId = 0n;
    });

    it("Should allow owner to set cabinet name", async function () {
      const newName = "Updated Cabinet";

      const hash = await cabinetContract.write.setCabinetName([
        tokenId,
        newName
      ], { account: user1.account });
      await publicClient.waitForTransactionReceipt({ hash });

      const [metadata] = await cabinetContract.read.getCabinetInfo([tokenId]);
      expect(metadata.name).to.equal(newName);
    });

    it("Should allow owner to configure cabinet", async function () {
      const newConfig = {
        playPrice: parseEther("0.05"),
        maxItems: 20n,
        platformFeeRate: 750n, // 7.5%
        feeRecipient: feeRecipient.account.address,
        allowsCustomOdds: false
      };

      const hash = await cabinetContract.write.setCabinetConfig([
        tokenId,
        newConfig
      ], { account: user1.account });
      await publicClient.waitForTransactionReceipt({ hash });

      const [, config] = await cabinetContract.read.getCabinetInfo([tokenId]);
      expect(config.playPrice).to.equal(newConfig.playPrice);
      expect(config.maxItems).to.equal(newConfig.maxItems);
      expect(config.platformFeeRate).to.equal(newConfig.platformFeeRate);
      expect(config.allowsCustomOdds).to.equal(newConfig.allowsCustomOdds);
    });

    it("Should revert when non-owner tries to configure", async function () {
      const newConfig = {
        playPrice: parseEther("0.05"),
        maxItems: 20n,
        platformFeeRate: 750n,
        feeRecipient: feeRecipient.account.address,
        allowsCustomOdds: false
      };

      await expect(
        cabinetContract.write.setCabinetConfig([
          tokenId,
          newConfig
        ], { account: user2.account })
      ).to.be.rejected;
    });

    it("Should revert with invalid configuration", async function () {
      // Invalid play price (zero)
      const invalidConfig1 = {
        playPrice: 0n,
        maxItems: 20n,
        platformFeeRate: 750n,
        feeRecipient: feeRecipient.account.address,
        allowsCustomOdds: false
      };

      await expect(
        cabinetContract.write.setCabinetConfig([
          tokenId,
          invalidConfig1
        ], { account: user1.account })
      ).to.be.rejected;

      // Invalid max items (too high)
      const invalidConfig2 = {
        playPrice: parseEther("0.01"),
        maxItems: 100n,
        platformFeeRate: 750n,
        feeRecipient: feeRecipient.account.address,
        allowsCustomOdds: false
      };

      await expect(
        cabinetContract.write.setCabinetConfig([
          tokenId,
          invalidConfig2
        ], { account: user1.account })
      ).to.be.rejected;

      // Invalid platform fee rate (too high)
      const invalidConfig3 = {
        playPrice: parseEther("0.01"),
        maxItems: 20n,
        platformFeeRate: 1500n, // 15% > 10% max
        feeRecipient: feeRecipient.account.address,
        allowsCustomOdds: false
      };

      await expect(
        cabinetContract.write.setCabinetConfig([
          tokenId,
          invalidConfig3
        ], { account: user1.account })
      ).to.be.rejected;
    });
  });

  describe("Cabinet Status Management", function () {
    let tokenId: bigint;

    beforeEach(async function () {
      const hash = await cabinetContract.write.mintCabinet([
        user1.account.address,
        "Test Cabinet"
      ], { account: deployer.account });
      await publicClient.waitForTransactionReceipt({ hash });
      tokenId = 0n;
    });

    it("Should allow owner to activate cabinet", async function () {
      const hash = await cabinetContract.write.activateCabinet([tokenId], { account: user1.account });
      await publicClient.waitForTransactionReceipt({ hash });

      const [metadata] = await cabinetContract.read.getCabinetInfo([tokenId]);
      expect(metadata.isActive).to.be.true;
    });

    it("Should allow owner to deactivate cabinet", async function () {
      // First activate
      let hash = await cabinetContract.write.activateCabinet([tokenId], { account: user1.account });
      await publicClient.waitForTransactionReceipt({ hash });

      // Then deactivate
      hash = await cabinetContract.write.deactivateCabinet([tokenId], { account: user1.account });
      await publicClient.waitForTransactionReceipt({ hash });

      const [metadata] = await cabinetContract.read.getCabinetInfo([tokenId]);
      expect(metadata.isActive).to.be.false;
    });

    it("Should revert when non-owner tries to change status", async function () {
      await expect(
        cabinetContract.write.activateCabinet([tokenId], { account: user2.account })
      ).to.be.rejected;

      await expect(
        cabinetContract.write.deactivateCabinet([tokenId], { account: user2.account })
      ).to.be.rejected;
    });
  });

  describe("Token URI and Metadata", function () {
    let tokenId: bigint;

    beforeEach(async function () {
      const hash = await cabinetContract.write.mintCabinet([
        user1.account.address,
        "Test Cabinet"
      ], { account: deployer.account });
      await publicClient.waitForTransactionReceipt({ hash });
      tokenId = 0n;
    });

    it("Should generate valid token URI", async function () {
      const tokenURI = await cabinetContract.read.tokenURI([tokenId]);

      expect(tokenURI).to.be.a("string");
      expect(tokenURI).to.include("data:application/json;base64,");

      // Decode and verify JSON structure
      const base64Data = tokenURI.replace("data:application/json;base64,", "");
      const jsonData = JSON.parse(Buffer.from(base64Data, "base64").toString());

      expect(jsonData).to.have.property("name");
      expect(jsonData).to.have.property("description");
      expect(jsonData).to.have.property("image");
      expect(jsonData).to.have.property("attributes");
      expect(jsonData.attributes).to.be.an("array");
    });

    it("Should generate valid SVG image", async function () {
      const tokenURI = await cabinetContract.read.tokenURI([tokenId]);
      const base64Data = tokenURI.replace("data:application/json;base64,", "");
      const jsonData = JSON.parse(Buffer.from(base64Data, "base64").toString());

      expect(jsonData.image).to.include("data:image/svg+xml;base64,");

      // Decode SVG
      const svgBase64 = jsonData.image.replace("data:image/svg+xml;base64,", "");
      const svgData = Buffer.from(svgBase64, "base64").toString();

      expect(svgData).to.include("<svg");
      expect(svgData).to.include("</svg>");
      expect(svgData).to.include("Test Cabinet");
    });

    it("Should revert for non-existent token", async function () {
      await expect(
        cabinetContract.read.tokenURI([999n])
      ).to.be.rejected;
    });
  });

  describe("Access Control and Security", function () {
    it("Should allow platform admin to update fee recipient", async function () {
      const newRecipient = user2.account.address;

      const hash = await cabinetContract.write.updatePlatformFeeRecipient([
        newRecipient
      ], { account: deployer.account });
      await publicClient.waitForTransactionReceipt({ hash });

      const updatedRecipient = await cabinetContract.read.platformFeeRecipient();
      expect(getAddress(updatedRecipient)).to.equal(getAddress(newRecipient));
    });

    it("Should allow emergency responder to pause/unpause", async function () {
      // Pause
      let hash = await cabinetContract.write.pause([], { account: deployer.account });
      await publicClient.waitForTransactionReceipt({ hash });

      const paused = await cabinetContract.read.paused();
      expect(paused).to.be.true;

      // Unpause
      hash = await cabinetContract.write.unpause([], { account: deployer.account });
      await publicClient.waitForTransactionReceipt({ hash });

      const unpaused = await cabinetContract.read.paused();
      expect(unpaused).to.be.false;
    });

    it("Should revert operations when paused", async function () {
      // Pause contract
      const hash = await cabinetContract.write.pause([], { account: deployer.account });
      await publicClient.waitForTransactionReceipt({ hash });

      // Try to mint (should fail)
      await expect(
        cabinetContract.write.mintCabinet([
          user1.account.address,
          "Test Cabinet"
        ], { account: deployer.account })
      ).to.be.rejected;
    });

    it("Should support ERC165 interface detection", async function () {
      // ERC721 interface ID
      const ERC721_INTERFACE_ID = "0x80ac58cd";
      const supportsERC721 = await cabinetContract.read.supportsInterface([ERC721_INTERFACE_ID]);
      expect(supportsERC721).to.be.true;

      // AccessControl interface ID
      const ACCESS_CONTROL_INTERFACE_ID = "0x7965db0b";
      const supportsAccessControl = await cabinetContract.read.supportsInterface([ACCESS_CONTROL_INTERFACE_ID]);
      expect(supportsAccessControl).to.be.true;
    });
  });

  describe("Gas Optimization", function () {
    it("Should mint cabinet within gas limits", async function () {
      const hash = await cabinetContract.write.mintCabinet([
        user1.account.address,
        "Test Cabinet"
      ], { account: deployer.account });

      const receipt = await publicClient.waitForTransactionReceipt({ hash });

      // Should be under 200k gas as specified in requirements
      expect(Number(receipt.gasUsed)).to.be.lessThan(200000);
    });

    it("Should configure cabinet within gas limits", async function () {
      // First mint a cabinet
      const mintHash = await cabinetContract.write.mintCabinet([
        user1.account.address,
        "Test Cabinet"
      ], { account: deployer.account });
      await publicClient.waitForTransactionReceipt({ mintHash });

      // Then configure it
      const newConfig = {
        playPrice: parseEther("0.05"),
        maxItems: 20n,
        platformFeeRate: 750n,
        feeRecipient: feeRecipient.account.address,
        allowsCustomOdds: false
      };

      const configHash = await cabinetContract.write.setCabinetConfig([
        0n,
        newConfig
      ], { account: user1.account });

      const receipt = await publicClient.waitForTransactionReceipt({ configHash });

      // Should be under 100k gas as specified in requirements
      expect(Number(receipt.gasUsed)).to.be.lessThan(100000);
    });
  });

  describe("Integration with TuuCoin", function () {
    let tokenId: bigint;

    beforeEach(async function () {
      const hash = await cabinetContract.write.mintCabinet([
        user1.account.address,
        "Test Cabinet"
      ], { account: deployer.account });
      await publicClient.waitForTransactionReceipt({ hash });
      tokenId = 0n;
    });

    it("Should register cabinet with TuuCoin on mint", async function () {
      // Check if cabinet is registered in TuuCoin
      const isRegistered = await tuuCoinContract.read.isCabinetRegistered([tokenId]);
      expect(isRegistered).to.be.true;
    });

    it("Should update TuuCoin status when cabinet is activated/deactivated", async function () {
      // Activate cabinet
      let hash = await cabinetContract.write.activateCabinet([tokenId], { account: user1.account });
      await publicClient.waitForTransactionReceipt({ hash });

      // Check status in TuuCoin
      let cabinetInfo = await tuuCoinContract.read.getCabinetInfo([tokenId]);
      expect(cabinetInfo.isActive).to.be.true;

      // Deactivate cabinet
      hash = await cabinetContract.write.deactivateCabinet([tokenId], { account: user1.account });
      await publicClient.waitForTransactionReceipt({ hash });

      // Check status in TuuCoin again
      cabinetInfo = await tuuCoinContract.read.getCabinetInfo([tokenId]);
      expect(cabinetInfo.isActive).to.be.false;
    });
  });
});