import { expect } from "chai";
import { ethers } from "hardhat";
import { TuuKeepAccessControl } from "../../../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("TuuKeepAccessControl", function () {
  let accessControl: TuuKeepAccessControl;
  let owner: SignerWithAddress;
  let manager: SignerWithAddress;
  let operator: SignerWithAddress;
  let user: SignerWithAddress;

  beforeEach(async function () {
    [owner, manager, operator, user] = await ethers.getSigners();

    const TuuKeepAccessControlFactory = await ethers.getContractFactory("TuuKeepAccessControl");
    accessControl = await TuuKeepAccessControlFactory.deploy();
    await accessControl.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should deploy successfully", async function () {
      expect(await accessControl.getAddress()).to.be.properAddress;
    });

    it("Should set deployer as default admin and platform admin", async function () {
      const DEFAULT_ADMIN_ROLE = await accessControl.DEFAULT_ADMIN_ROLE();
      const PLATFORM_ADMIN_ROLE = await accessControl.PLATFORM_ADMIN_ROLE();

      expect(await accessControl.hasRole(DEFAULT_ADMIN_ROLE, owner.address)).to.be.true;
      expect(await accessControl.hasRole(PLATFORM_ADMIN_ROLE, owner.address)).to.be.true;
    });

    it("Should set up correct role hierarchy", async function () {
      const PLATFORM_ADMIN_ROLE = await accessControl.PLATFORM_ADMIN_ROLE();
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();
      const MARKETPLACE_OPERATOR_ROLE = await accessControl.MARKETPLACE_OPERATOR_ROLE();
      const RANDOMNESS_CONSUMER_ROLE = await accessControl.RANDOMNESS_CONSUMER_ROLE();

      expect(await accessControl.getRoleAdmin(CABINET_MANAGER_ROLE)).to.equal(PLATFORM_ADMIN_ROLE);
      expect(await accessControl.getRoleAdmin(MARKETPLACE_OPERATOR_ROLE)).to.equal(PLATFORM_ADMIN_ROLE);
      expect(await accessControl.getRoleAdmin(RANDOMNESS_CONSUMER_ROLE)).to.equal(PLATFORM_ADMIN_ROLE);
    });
  });

  describe("Role Management", function () {
    it("Should grant roles correctly", async function () {
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();

      await accessControl.grantRole(CABINET_MANAGER_ROLE, manager.address);
      expect(await accessControl.hasRole(CABINET_MANAGER_ROLE, manager.address)).to.be.true;
    });

    it("Should revoke roles correctly", async function () {
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();

      await accessControl.grantRole(CABINET_MANAGER_ROLE, manager.address);
      await accessControl.revokeRole(CABINET_MANAGER_ROLE, manager.address);
      expect(await accessControl.hasRole(CABINET_MANAGER_ROLE, manager.address)).to.be.false;
    });
  });

  describe("Role Expiry System", function () {
    it("Should grant role with expiry", async function () {
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();
      const duration = 3600; // 1 hour

      await expect(accessControl.grantRoleWithExpiry(CABINET_MANAGER_ROLE, manager.address, duration))
        .to.emit(accessControl, "RoleGrantedWithExpiry")
        .withArgs(CABINET_MANAGER_ROLE, manager.address, anyValue, owner.address);

      expect(await accessControl.hasActiveRole(CABINET_MANAGER_ROLE, manager.address)).to.be.true;
    });

    it("Should reject role with zero duration", async function () {
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();

      await expect(
        accessControl.grantRoleWithExpiry(CABINET_MANAGER_ROLE, manager.address, 0)
      ).to.be.revertedWith("TuuKeepAccessControl: duration must be positive");
    });

    it("Should reject role with invalid account", async function () {
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();

      await expect(
        accessControl.grantRoleWithExpiry(CABINET_MANAGER_ROLE, ethers.ZeroAddress, 3600)
      ).to.be.revertedWith("TuuKeepAccessControl: invalid account");
    });

    it("Should check role expiry correctly", async function () {
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();
      const duration = 3600; // 1 hour

      await accessControl.grantRoleWithExpiry(CABINET_MANAGER_ROLE, manager.address, duration);

      // Should be active initially
      expect(await accessControl.hasActiveRole(CABINET_MANAGER_ROLE, manager.address)).to.be.true;

      // Fast forward time beyond expiry
      await time.increase(duration + 1);

      // Should be inactive after expiry
      expect(await accessControl.hasActiveRole(CABINET_MANAGER_ROLE, manager.address)).to.be.false;
    });

    it("Should revoke expired roles", async function () {
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();
      const duration = 3600; // 1 hour

      await accessControl.grantRoleWithExpiry(CABINET_MANAGER_ROLE, manager.address, duration);

      // Fast forward time beyond expiry
      await time.increase(duration + 1);

      await expect(accessControl.revokeExpiredRole(CABINET_MANAGER_ROLE, manager.address))
        .to.emit(accessControl, "ExpiredRolesRevoked")
        .withArgs(CABINET_MANAGER_ROLE, manager.address, anyValue);

      expect(await accessControl.hasRole(CABINET_MANAGER_ROLE, manager.address)).to.be.false;
    });

    it("Should reject revoking non-expired roles", async function () {
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();
      const duration = 3600; // 1 hour

      await accessControl.grantRoleWithExpiry(CABINET_MANAGER_ROLE, manager.address, duration);

      await expect(
        accessControl.revokeExpiredRole(CABINET_MANAGER_ROLE, manager.address)
      ).to.be.revertedWith("TuuKeepAccessControl: role not expired");
    });

    it("Should extend role expiry", async function () {
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();
      const initialDuration = 3600; // 1 hour
      const extension = 1800; // 30 minutes

      await accessControl.grantRoleWithExpiry(CABINET_MANAGER_ROLE, manager.address, initialDuration);

      const [initialExpiry] = await accessControl.getRoleExpiry(CABINET_MANAGER_ROLE, manager.address);

      await accessControl.extendRoleExpiry(CABINET_MANAGER_ROLE, manager.address, extension);

      const [extendedExpiry] = await accessControl.getRoleExpiry(CABINET_MANAGER_ROLE, manager.address);
      expect(extendedExpiry).to.equal(initialExpiry + BigInt(extension));
    });
  });

  describe("Batch Operations", function () {
    it("Should batch revoke expired roles", async function () {
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();
      const MARKETPLACE_OPERATOR_ROLE = await accessControl.MARKETPLACE_OPERATOR_ROLE();
      const duration = 3600; // 1 hour

      await accessControl.grantRoleWithExpiry(CABINET_MANAGER_ROLE, manager.address, duration);
      await accessControl.grantRoleWithExpiry(MARKETPLACE_OPERATOR_ROLE, operator.address, duration);

      // Fast forward time beyond expiry
      await time.increase(duration + 1);

      const roles = [CABINET_MANAGER_ROLE, MARKETPLACE_OPERATOR_ROLE];
      const accounts = [manager.address, operator.address];

      await accessControl.batchRevokeExpiredRoles(roles, accounts);

      expect(await accessControl.hasRole(CABINET_MANAGER_ROLE, manager.address)).to.be.false;
      expect(await accessControl.hasRole(MARKETPLACE_OPERATOR_ROLE, operator.address)).to.be.false;
    });

    it("Should reject batch operations with mismatched array lengths", async function () {
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();

      const roles = [CABINET_MANAGER_ROLE];
      const accounts = [manager.address, operator.address];

      await expect(
        accessControl.batchRevokeExpiredRoles(roles, accounts)
      ).to.be.revertedWith("TuuKeepAccessControl: arrays length mismatch");
    });
  });

  describe("Activity Tracking", function () {
    it("Should track user activity", async function () {
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();

      await accessControl.grantRole(CABINET_MANAGER_ROLE, manager.address);

      await expect(accessControl.trackActivity(manager.address, CABINET_MANAGER_ROLE))
        .to.emit(accessControl, "ActivityTracked")
        .withArgs(manager.address, CABINET_MANAGER_ROLE, anyValue);

      const lastActivity = await accessControl.getLastActivity(manager.address);
      expect(lastActivity).to.be.greaterThan(0);
    });

    it("Should reject tracking activity for accounts without active roles", async function () {
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();

      await expect(
        accessControl.trackActivity(user.address, CABINET_MANAGER_ROLE)
      ).to.be.revertedWith("TuuKeepAccessControl: account lacks active role");
    });
  });

  describe("Role Information", function () {
    it("Should return correct role expiry information", async function () {
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();
      const duration = 3600; // 1 hour

      await accessControl.grantRoleWithExpiry(CABINET_MANAGER_ROLE, manager.address, duration);

      const [expiryTime, isActive] = await accessControl.getRoleExpiry(CABINET_MANAGER_ROLE, manager.address);
      expect(isActive).to.be.true;
      expect(expiryTime).to.be.greaterThan(0);
    });

    it("Should return zero expiry for permanent roles", async function () {
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();

      await accessControl.grantRole(CABINET_MANAGER_ROLE, manager.address);

      const [expiryTime, isActive] = await accessControl.getRoleExpiry(CABINET_MANAGER_ROLE, manager.address);
      expect(isActive).to.be.false;
      expect(expiryTime).to.equal(0);
    });
  });

  describe("Access Control", function () {
    it("Should only allow role admin to grant roles with expiry", async function () {
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();

      await expect(
        accessControl.connect(user).grantRoleWithExpiry(CABINET_MANAGER_ROLE, manager.address, 3600)
      ).to.be.reverted;
    });

    it("Should only allow role admin to extend role expiry", async function () {
      const CABINET_MANAGER_ROLE = await accessControl.CABINET_MANAGER_ROLE();

      await accessControl.grantRoleWithExpiry(CABINET_MANAGER_ROLE, manager.address, 3600);

      await expect(
        accessControl.connect(user).extendRoleExpiry(CABINET_MANAGER_ROLE, manager.address, 1800)
      ).to.be.reverted;
    });
  });
});

// Helper for testing events with dynamic values
const anyValue = (value: any) => true;