import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * TuuKeepTierSale Ignition Deployment Module
 *
 * Deploys the TuuKeepTierSale contract for tier-based cabinet NFT sales.
 * This contract manages phased sales with automatic tier progression
 * and revenue distribution. Requires TuuKeepCabinet to be deployed first.
 */
const TuuKeepTierSaleModule = buildModule("TuuKeepTierSale", (m) => {
  // Parameters that can be overridden during deployment
  const cabinetContract = m.getParameter("cabinetContract", "");
  const platformTreasury = m.getParameter("platformTreasury", "");
  const admin = m.getParameter("admin", "");

  // Validate required parameters
  if (!cabinetContract) {
    throw new Error("cabinetContract parameter is required");
  }
  if (!platformTreasury) {
    throw new Error("platformTreasury parameter is required");
  }
  if (!admin) {
    throw new Error("admin parameter is required");
  }

  // Deploy TuuKeepTierSale with cabinet integration
  const tierSale = m.contract("TuuKeepTierSale", [
    cabinetContract,
    platformTreasury,
    admin,
  ]);

  return { tierSale };
});

export default TuuKeepTierSaleModule;

/**
 * Example deployment commands:
 *
 * Local deployment:
 * npx hardhat ignition deploy ignition/modules/TuuKeepTierSale.ts \
 *   --parameters '{"cabinetContract":"0x...", "platformTreasury":"0x...", "admin":"0x..."}'
 *
 * KUB Testnet deployment:
 * npx hardhat ignition deploy ignition/modules/TuuKeepTierSale.ts \
 *   --network kubTestnet \
 *   --parameters '{"cabinetContract":"0x...", "platformTreasury":"0x...", "admin":"0x..."}'
 *
 * KUB Mainnet deployment:
 * npx hardhat ignition deploy ignition/modules/TuuKeepTierSale.ts \
 *   --network kubMainnet \
 *   --parameters '{"cabinetContract":"0x...", "platformTreasury":"0x...", "admin":"0x..."}'
 *
 * Verification on KubScan:
 * npx hardhat verify --network kubTestnet DEPLOYED_CONTRACT_ADDRESS \
 *   "CABINET_CONTRACT_ADDRESS" "PLATFORM_TREASURY_ADDRESS" "ADMIN_ADDRESS"
 * npx hardhat verify --network kubMainnet DEPLOYED_CONTRACT_ADDRESS \
 *   "CABINET_CONTRACT_ADDRESS" "PLATFORM_TREASURY_ADDRESS" "ADMIN_ADDRESS"
 *
 * Post-deployment configuration:
 * - Create initial sale phases with tier configurations
 * - Set up tier pricing and quantity limits
 * - Configure phase timing and transition rules
 * - Grant MINTER_ROLE to tier sale contract in cabinet contract
 */