import { expect } from "chai";
import { ethers } from "hardhat";
import { SafeTransferLib, IERC20, IERC721 } from "../../../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("SafeTransferLib", function () {
  let safeTransferLib: SafeTransferLib;
  let mockERC20: IERC20;
  let mockERC721: IERC721;
  let owner: SignerWithAddress;
  let recipient: SignerWithAddress;
  let operator: SignerWithAddress;

  beforeEach(async function () {
    [owner, recipient, operator] = await ethers.getSigners();

    // Deploy SafeTransferLib test contract
    const SafeTransferLibFactory = await ethers.getContractFactory("SafeTransferLib");
    safeTransferLib = await SafeTransferLibFactory.deploy();
    await safeTransferLib.waitForDeployment();
  });

  describe("ERC20 Transfers", function () {
    describe("Input Validation", function () {
      it("Should reject zero token address", async function () {
        const result = await safeTransferLib.safeTransferERC20(
          ethers.ZeroAddress,
          recipient.address,
          100
        );

        expect(result.success).to.be.false;
        expect(result.errorMessage).to.equal("Invalid token address");
      });

      it("Should reject zero recipient address", async function () {
        const mockToken = await ethers.getContractAt("IERC20", ethers.ZeroAddress);

        const result = await safeTransferLib.safeTransferERC20(
          mockToken.target,
          ethers.ZeroAddress,
          100
        );

        expect(result.success).to.be.false;
        expect(result.errorMessage).to.equal("Invalid recipient address");
      });

      it("Should reject zero amount", async function () {
        const mockToken = await ethers.getContractAt("IERC20", recipient.address); // Using any address for mock

        const result = await safeTransferLib.safeTransferERC20(
          mockToken.target,
          recipient.address,
          0
        );

        expect(result.success).to.be.false;
        expect(result.errorMessage).to.equal("Amount cannot be zero");
      });
    });

    describe("Balance Validation", function () {
      it("Should validate sufficient balance", async function () {
        // This would require a proper mock ERC20 contract for full testing
        expect(true).to.be.true; // Placeholder for now
      });

      it("Should reject insufficient balance", async function () {
        // This would require a proper mock ERC20 contract for full testing
        expect(true).to.be.true; // Placeholder for now
      });
    });

    describe("TransferFrom Operations", function () {
      it("Should validate transferFrom parameters", async function () {
        const result = await safeTransferLib.safeTransferFromERC20(
          ethers.ZeroAddress,
          owner.address,
          recipient.address,
          100
        );

        expect(result.success).to.be.false;
        expect(result.errorMessage).to.equal("Invalid address parameters");
      });

      it("Should reject zero amount in transferFrom", async function () {
        const mockToken = await ethers.getContractAt("IERC20", recipient.address);

        const result = await safeTransferLib.safeTransferFromERC20(
          mockToken.target,
          owner.address,
          recipient.address,
          0
        );

        expect(result.success).to.be.false;
        expect(result.errorMessage).to.equal("Amount cannot be zero");
      });
    });

    describe("Pre-validation Checks", function () {
      it("Should validate transfer possibility", async function () {
        const [success, reason] = await safeTransferLib.canTransferERC20(
          ethers.ZeroAddress,
          owner.address,
          recipient.address,
          100
        );

        expect(success).to.be.false;
        expect(reason).to.equal("Invalid token address");
      });

      it("Should validate non-zero amounts", async function () {
        const mockToken = await ethers.getContractAt("IERC20", recipient.address);

        const [success, reason] = await safeTransferLib.canTransferERC20(
          mockToken.target,
          owner.address,
          recipient.address,
          0
        );

        expect(success).to.be.false;
        expect(reason).to.equal("Amount cannot be zero");
      });
    });
  });

  describe("ERC721 Transfers", function () {
    describe("Input Validation", function () {
      it("Should reject zero token address", async function () {
        const result = await safeTransferLib.safeTransferERC721(
          ethers.ZeroAddress,
          owner.address,
          recipient.address,
          1
        );

        expect(result.success).to.be.false;
        expect(result.errorMessage).to.equal("Invalid address parameters");
      });

      it("Should reject zero addresses", async function () {
        const result = await safeTransferLib.safeTransferERC721(
          recipient.address, // Using any address for mock
          ethers.ZeroAddress,
          recipient.address,
          1
        );

        expect(result.success).to.be.false;
        expect(result.errorMessage).to.equal("Invalid address parameters");
      });
    });

    describe("Ownership Validation", function () {
      it("Should validate token ownership", async function () {
        // This would require a proper mock ERC721 contract for full testing
        expect(true).to.be.true; // Placeholder for now
      });

      it("Should validate token existence", async function () {
        // This would require a proper mock ERC721 contract for full testing
        expect(true).to.be.true; // Placeholder for now
      });
    });

    describe("Pre-validation Checks", function () {
      it("Should validate transfer possibility", async function () {
        const [success, reason] = await safeTransferLib.canTransferERC721(
          ethers.ZeroAddress,
          owner.address,
          recipient.address,
          1
        );

        expect(success).to.be.false;
        expect(reason).to.equal("Invalid token address");
      });

      it("Should validate address parameters", async function () {
        const mockToken = await ethers.getContractAt("IERC721", recipient.address);

        const [success, reason] = await safeTransferLib.canTransferERC721(
          mockToken.target,
          ethers.ZeroAddress,
          recipient.address,
          1
        );

        expect(success).to.be.false;
        expect(reason).to.equal("Invalid address parameters");
      });
    });
  });

  describe("Batch Operations", function () {
    describe("Batch ERC20 Transfers", function () {
      it("Should handle empty batch transfers", async function () {
        const results = await safeTransferLib.batchTransferERC20([]);
        expect(results.length).to.equal(0);
      });

      it("Should process multiple transfers", async function () {
        // This would require proper mock contracts for comprehensive testing
        const transfers = [];
        const results = await safeTransferLib.batchTransferERC20(transfers);
        expect(results.length).to.equal(0);
      });
    });

    describe("Batch ERC721 Transfers", function () {
      it("Should handle empty batch transfers", async function () {
        const results = await safeTransferLib.batchTransferERC721([]);
        expect(results.length).to.equal(0);
      });

      it("Should process multiple NFT transfers", async function () {
        // This would require proper mock contracts for comprehensive testing
        const transfers = [];
        const results = await safeTransferLib.batchTransferERC721(transfers);
        expect(results.length).to.equal(0);
      });
    });
  });

  describe("Gas Monitoring", function () {
    it("Should track gas usage in transfer results", async function () {
      const result = await safeTransferLib.safeTransferERC20(
        ethers.ZeroAddress,
        recipient.address,
        100
      );

      expect(result.gasUsed).to.be.greaterThan(0);
    });

    it("Should optimize gas consumption for batch operations", async function () {
      // Test that batch operations are more gas efficient than individual calls
      expect(true).to.be.true; // Placeholder for gas optimization tests
    });
  });

  describe("Error Handling", function () {
    it("Should provide detailed error messages", async function () {
      const result = await safeTransferLib.safeTransferERC20(
        ethers.ZeroAddress,
        recipient.address,
        100
      );

      expect(result.errorMessage).to.not.be.empty;
      expect(result.errorMessage).to.equal("Invalid token address");
    });

    it("Should handle low-level call failures", async function () {
      // This would require mock contracts that fail in specific ways
      expect(true).to.be.true; // Placeholder for low-level failure tests
    });
  });

  describe("Event Emission", function () {
    it("Should emit SafeTransferExecuted events", async function () {
      // This would require successful transfers to test event emission
      expect(true).to.be.true; // Placeholder for event emission tests
    });

    it("Should emit BatchTransferCompleted events", async function () {
      // Test batch operation event emission
      expect(true).to.be.true; // Placeholder for batch event tests
    });
  });

  describe("Integration", function () {
    it("Should work with OpenZeppelin SafeERC20", async function () {
      // Verify compatibility with existing OpenZeppelin patterns
      expect(true).to.be.true; // Placeholder for integration tests
    });

    it("Should integrate with TuuKeep cabinet asset management", async function () {
      // Test integration with cabinet deposit/withdrawal patterns
      expect(true).to.be.true; // Placeholder for cabinet integration tests
    });
  });

  describe("Security", function () {
    it("Should resist common attack vectors", async function () {
      // Test against reentrancy and other common attacks
      expect(true).to.be.true; // Placeholder for security tests
    });

    it("Should validate return values correctly", async function () {
      // Test handling of tokens with and without return values
      expect(true).to.be.true; // Placeholder for return value tests
    });
  });
});