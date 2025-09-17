import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * TuuKeepMarketplace Ignition Deployment Module
 *
 * Deploys the TuuKeepMarketplace contract with proper dependencies
 * and initial configuration for P2P cabinet NFT trading.
 */
const TuuKeepMarketplaceModule = buildModule("TuuKeepMarketplace", (m) => {
  // Parameters that can be overridden during deployment
  const cabinetContractAddress = m.getParameter("cabinetContract", "");
  const accessControlAddress = m.getParameter("accessControl", "");
  const platformFeeRecipient = m.getParameter("platformFeeRecipient", "");

  // Validate required parameters
  if (!cabinetContractAddress) {
    throw new Error("cabinetContract parameter is required");
  }
  if (!accessControlAddress) {
    throw new Error("accessControl parameter is required");
  }
  if (!platformFeeRecipient) {
    throw new Error("platformFeeRecipient parameter is required");
  }

  // Deploy TuuKeepMarketplace
  const marketplace = m.contract("TuuKeepMarketplace", [
    cabinetContractAddress,
    accessControlAddress,
    platformFeeRecipient,
  ]);

  return { marketplace };
});

export default TuuKeepMarketplaceModule;

/**
 * Example deployment commands:
 *
 * Local deployment:
 * npx hardhat ignition deploy ignition/modules/TuuKeepMarketplace.ts \
 *   --parameters '{"cabinetContract":"0x...", "accessControl":"0x...", "platformFeeRecipient":"0x..."}'
 *
 * KUB Testnet deployment:
 * npx hardhat ignition deploy ignition/modules/TuuKeepMarketplace.ts \
 *   --network kubTestnet \
 *   --parameters '{"cabinetContract":"0x...", "accessControl":"0x...", "platformFeeRecipient":"0x..."}'
 *
 * Verification on KubScan:
 * npx hardhat verify --network kubTestnet DEPLOYED_CONTRACT_ADDRESS \
 *   "CABINET_CONTRACT_ADDRESS" "ACCESS_CONTROL_ADDRESS" "PLATFORM_FEE_RECIPIENT"
 */