import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * TuuKeepCabinet Ignition Deployment Module
 *
 * Deploys the TuuKeepCabinet contract, the core NFT contract for the TuuKeep ecosystem.
 * This contract manages cabinet NFTs, gacha gameplay mechanics, and asset management.
 * Requires TuuKeepAccessControl, TuuCoin, and Randomness contracts to be deployed first.
 */
const TuuKeepCabinetModule = buildModule("TuuKeepCabinet", (m) => {
  // Parameters that can be overridden during deployment
  const accessControlAddress = m.getParameter("accessControl", "");
  const tuuCoinAddress = m.getParameter("tuuCoin", "");
  const randomnessAddress = m.getParameter("randomness", "");
  const platformFeeRecipient = m.getParameter("platformFeeRecipient", "");

  // Validate required parameters
  if (!accessControlAddress) {
    throw new Error("accessControl parameter is required");
  }
  if (!tuuCoinAddress) {
    throw new Error("tuuCoin parameter is required");
  }
  if (!randomnessAddress) {
    throw new Error("randomness parameter is required");
  }
  if (!platformFeeRecipient) {
    throw new Error("platformFeeRecipient parameter is required");
  }

  // Deploy TuuKeepCabinet with all dependencies
  const cabinet = m.contract("TuuKeepCabinet", [
    accessControlAddress,
    tuuCoinAddress,
    randomnessAddress,
    platformFeeRecipient,
  ]);

  return { cabinet };
});

export default TuuKeepCabinetModule;

/**
 * Example deployment commands:
 *
 * Local deployment:
 * npx hardhat ignition deploy ignition/modules/TuuKeepCabinet.ts \
 *   --parameters '{"accessControl":"0x...", "tuuCoin":"0x...", "randomness":"0x...", "platformFeeRecipient":"0x..."}'
 *
 * KUB Testnet deployment:
 * npx hardhat ignition deploy ignition/modules/TuuKeepCabinet.ts \
 *   --network kubTestnet \
 *   --parameters '{"accessControl":"0x...", "tuuCoin":"0x...", "randomness":"0x...", "platformFeeRecipient":"0x..."}'
 *
 * KUB Mainnet deployment:
 * npx hardhat ignition deploy ignition/modules/TuuKeepCabinet.ts \
 *   --network kubMainnet \
 *   --parameters '{"accessControl":"0x...", "tuuCoin":"0x...", "randomness":"0x...", "platformFeeRecipient":"0x..."}'
 *
 * Verification on KubScan:
 * npx hardhat verify --network kubTestnet DEPLOYED_CONTRACT_ADDRESS \
 *   "ACCESS_CONTROL_ADDRESS" "TUUCOIN_ADDRESS" "RANDOMNESS_ADDRESS" "PLATFORM_FEE_RECIPIENT"
 * npx hardhat verify --network kubMainnet DEPLOYED_CONTRACT_ADDRESS \
 *   "ACCESS_CONTROL_ADDRESS" "TUUCOIN_ADDRESS" "RANDOMNESS_ADDRESS" "PLATFORM_FEE_RECIPIENT"
 *
 * Post-deployment configuration:
 * - Register cabinet contract as consumer in Randomness contract
 * - Grant CABINET_OPERATOR_ROLE to cabinet contract in TuuCoin
 * - Configure platform settings and admin roles
 * - Set up initial cabinet minting permissions
 */