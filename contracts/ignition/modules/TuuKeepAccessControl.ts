import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * TuuKeepAccessControl Ignition Deployment Module
 *
 * Deploys the TuuKeepAccessControl contract as the foundation
 * for role-based access control across the entire TuuKeep ecosystem.
 * This contract must be deployed first as all other contracts depend on it.
 */
const TuuKeepAccessControlModule = buildModule("TuuKeepAccessControl", (m) => {
  // Parameters for initial admin configuration
  const defaultAdmin = m.getParameter("defaultAdmin", "");

  // Validate required parameters
  if (!defaultAdmin) {
    throw new Error("defaultAdmin parameter is required for initial access control setup");
  }

  // Deploy TuuKeepAccessControl with default admin
  const accessControl = m.contract("TuuKeepAccessControl", [defaultAdmin]);

  return { accessControl };
});

export default TuuKeepAccessControlModule;

/**
 * Example deployment commands:
 *
 * Local deployment:
 * npx hardhat ignition deploy ignition/modules/TuuKeepAccessControl.ts \
 *   --parameters '{"defaultAdmin":"0x..."}'
 *
 * KUB Testnet deployment:
 * npx hardhat ignition deploy ignition/modules/TuuKeepAccessControl.ts \
 *   --network kubTestnet \
 *   --parameters '{"defaultAdmin":"0x..."}'
 *
 * KUB Mainnet deployment:
 * npx hardhat ignition deploy ignition/modules/TuuKeepAccessControl.ts \
 *   --network kubMainnet \
 *   --parameters '{"defaultAdmin":"0x..."}'
 *
 * Verification on KubScan:
 * npx hardhat verify --network kubTestnet DEPLOYED_CONTRACT_ADDRESS "DEFAULT_ADMIN_ADDRESS"
 * npx hardhat verify --network kubMainnet DEPLOYED_CONTRACT_ADDRESS "DEFAULT_ADMIN_ADDRESS"
 *
 * Post-deployment role setup (example):
 * - Grant PLATFORM_ADMIN_ROLE to platform administrators
 * - Grant EMERGENCY_RESPONDER_ROLE to emergency response team
 * - Grant MINTER_ROLE to cabinet and token minting contracts
 */