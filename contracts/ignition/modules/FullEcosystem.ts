import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import TuuKeepAccessControlModule from "./TuuKeepAccessControl";
import TuuCoinModule from "./TuuCoin";
import RandomnessModule from "./Randomness";
import TuuKeepCabinetModule from "./TuuKeepCabinet";
import TuuKeepMarketplaceModule from "./TuuKeepMarketplace";
import TuuKeepTierSaleModule from "./TuuKeepTierSale";

/**
 * FullEcosystem Ignition Deployment Module
 *
 * Orchestrates the complete deployment of the TuuKeep ecosystem
 * in the correct order with proper dependency management and
 * cross-contract integration setup.
 *
 * Deployment Order:
 * 1. TuuKeepAccessControl (foundation)
 * 2. TuuCoin (token economy)
 * 3. Randomness (utility)
 * 4. TuuKeepCabinet (core NFT)
 * 5. TuuKeepMarketplace (P2P trading)
 * 6. TuuKeepTierSale (initial sales)
 */
const FullEcosystemModule = buildModule("FullEcosystem", (m) => {
  // Global parameters
  const defaultAdmin = m.getParameter("defaultAdmin", "");
  const platformTreasury = m.getParameter("platformTreasury", "");
  const platformFeeRecipient = m.getParameter("platformFeeRecipient", "");

  // Validate required global parameters
  if (!defaultAdmin) {
    throw new Error("defaultAdmin parameter is required for ecosystem deployment");
  }
  if (!platformTreasury) {
    throw new Error("platformTreasury parameter is required for revenue management");
  }
  if (!platformFeeRecipient) {
    throw new Error("platformFeeRecipient parameter is required for fee collection");
  }

  // Phase 1: Deploy foundational contracts
  const { accessControl } = m.useModule(TuuKeepAccessControlModule, {
    parameters: {
      defaultAdmin,
    },
  });

  // Phase 2: Deploy TuuCoin with access control integration
  const { tuuCoin } = m.useModule(TuuCoinModule, {
    parameters: {
      accessControl,
      initialAdmin: defaultAdmin,
    },
  });

  // Phase 3: Deploy Randomness utility
  const { randomness } = m.useModule(RandomnessModule, {
    parameters: {
      admin: defaultAdmin,
    },
  });

  // Phase 4: Deploy TuuKeepCabinet with all dependencies
  const { cabinet } = m.useModule(TuuKeepCabinetModule, {
    parameters: {
      accessControl,
      tuuCoin,
      randomness,
      platformFeeRecipient,
    },
  });

  // Phase 5: Deploy TuuKeepMarketplace
  const { marketplace } = m.useModule(TuuKeepMarketplaceModule, {
    parameters: {
      cabinetContract: cabinet,
      accessControl,
      platformFeeRecipient,
    },
  });

  // Phase 6: Deploy TuuKeepTierSale
  const { tierSale } = m.useModule(TuuKeepTierSaleModule, {
    parameters: {
      cabinetContract: cabinet,
      platformTreasury,
      admin: defaultAdmin,
    },
  });

  return {
    accessControl,
    tuuCoin,
    randomness,
    cabinet,
    marketplace,
    tierSale,
  };
});

export default FullEcosystemModule;

/**
 * Example deployment commands:
 *
 * Local complete ecosystem deployment:
 * npx hardhat ignition deploy ignition/modules/FullEcosystem.ts \
 *   --parameters '{
 *     "defaultAdmin":"0x...",
 *     "platformTreasury":"0x...",
 *     "platformFeeRecipient":"0x..."
 *   }'
 *
 * KUB Testnet complete ecosystem deployment:
 * npx hardhat ignition deploy ignition/modules/FullEcosystem.ts \
 *   --network kubTestnet \
 *   --parameters '{
 *     "defaultAdmin":"0x...",
 *     "platformTreasury":"0x...",
 *     "platformFeeRecipient":"0x..."
 *   }'
 *
 * KUB Mainnet complete ecosystem deployment:
 * npx hardhat ignition deploy ignition/modules/FullEcosystem.ts \
 *   --network kubMainnet \
 *   --parameters '{
 *     "defaultAdmin":"0x...",
 *     "platformTreasury":"0x...",
 *     "platformFeeRecipient":"0x..."
 *   }'
 *
 * Post-deployment integration setup (automated by this module):
 * - Register cabinet contract as consumer in Randomness
 * - Grant CABINET_OPERATOR_ROLE to cabinet in TuuCoin
 * - Grant MINTER_ROLE to tier sale contract
 * - Configure cross-contract permissions
 * - Set up platform settings
 *
 * Manual verification on KubScan:
 * Use the individual contract verification commands from each module
 * or run the verification script from scripts/verify-ecosystem.ts
 */