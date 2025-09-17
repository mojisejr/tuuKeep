import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Randomness Ignition Deployment Module
 *
 * Deploys the Randomness utility contract that provides secure
 * on-chain pseudo-randomness for gacha mechanics across the TuuKeep ecosystem.
 * This contract uses multiple entropy sources for manipulation-resistant randomness.
 */
const RandomnessModule = buildModule("Randomness", (m) => {
  // Parameters that can be overridden during deployment
  const admin = m.getParameter("admin", "");

  // Validate required parameters
  if (!admin) {
    throw new Error("admin parameter is required for Randomness contract");
  }

  // Deploy Randomness utility contract
  const randomness = m.contract("Randomness", [admin]);

  return { randomness };
});

export default RandomnessModule;

/**
 * Example deployment commands:
 *
 * Local deployment:
 * npx hardhat ignition deploy ignition/modules/Randomness.ts \
 *   --parameters '{"admin":"0x..."}'
 *
 * KUB Testnet deployment:
 * npx hardhat ignition deploy ignition/modules/Randomness.ts \
 *   --network kubTestnet \
 *   --parameters '{"admin":"0x..."}'
 *
 * KUB Mainnet deployment:
 * npx hardhat ignition deploy ignition/modules/Randomness.ts \
 *   --network kubMainnet \
 *   --parameters '{"admin":"0x..."}'
 *
 * Verification on KubScan:
 * npx hardhat verify --network kubTestnet DEPLOYED_CONTRACT_ADDRESS "ADMIN_ADDRESS"
 * npx hardhat verify --network kubMainnet DEPLOYED_CONTRACT_ADDRESS "ADMIN_ADDRESS"
 *
 * Post-deployment configuration:
 * - Add cabinet contracts as consumers using addConsumer()
 * - Grant CONSUMER_ROLE to contracts that need randomness
 * - Test randomness generation with generateRandomNumber()
 */