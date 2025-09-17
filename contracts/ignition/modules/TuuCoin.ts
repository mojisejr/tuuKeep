import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * TuuCoin Ignition Deployment Module
 *
 * Deploys the TuuCoin contract with proper access control integration.
 * TuuCoin is the native token for the TuuKeep platform, featuring
 * controlled minting, burn-for-odds mechanics, and cabinet integration.
 */
const TuuCoinModule = buildModule("TuuCoin", (m) => {
  // Parameters that can be overridden during deployment
  const accessControlAddress = m.getParameter("accessControl", "");
  const initialAdmin = m.getParameter("initialAdmin", "");

  // Validate required parameters
  if (!accessControlAddress) {
    throw new Error("accessControl parameter is required");
  }
  if (!initialAdmin) {
    throw new Error("initialAdmin parameter is required");
  }

  // Deploy TuuCoin with access control and initial admin
  const tuuCoin = m.contract("TuuCoin", [
    accessControlAddress,
    initialAdmin,
  ]);

  return { tuuCoin };
});

export default TuuCoinModule;

/**
 * Example deployment commands:
 *
 * Local deployment:
 * npx hardhat ignition deploy ignition/modules/TuuCoin.ts \
 *   --parameters '{"accessControl":"0x...", "initialAdmin":"0x..."}'
 *
 * KUB Testnet deployment:
 * npx hardhat ignition deploy ignition/modules/TuuCoin.ts \
 *   --network kubTestnet \
 *   --parameters '{"accessControl":"0x...", "initialAdmin":"0x..."}'
 *
 * KUB Mainnet deployment:
 * npx hardhat ignition deploy ignition/modules/TuuCoin.ts \
 *   --network kubMainnet \
 *   --parameters '{"accessControl":"0x...", "initialAdmin":"0x..."}'
 *
 * Verification on KubScan:
 * npx hardhat verify --network kubTestnet DEPLOYED_CONTRACT_ADDRESS \
 *   "ACCESS_CONTROL_ADDRESS" "INITIAL_ADMIN_ADDRESS"
 * npx hardhat verify --network kubMainnet DEPLOYED_CONTRACT_ADDRESS \
 *   "ACCESS_CONTROL_ADDRESS" "INITIAL_ADMIN_ADDRESS"
 *
 * Post-deployment configuration:
 * - Configure emission rates for cabinet integration
 * - Register cabinet contracts for token minting
 * - Set up platform-specific emission multipliers
 */