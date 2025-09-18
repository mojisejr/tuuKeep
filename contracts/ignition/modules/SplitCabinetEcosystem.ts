import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import TuuKeepAccessControlModule from "./TuuKeepAccessControl";
import TuuCoinModule from "./TuuCoin";
import RandomnessModule from "./Randomness";
import TuuKeepCabinetCoreModule from "./TuuKeepCabinetCore";
import TuuKeepCabinetGameModule from "./TuuKeepCabinetGame";
import TuuKeepMarketplaceModule from "./TuuKeepMarketplace";
import TuuKeepTierSaleModule from "./TuuKeepTierSale";

const SplitCabinetEcosystemModule = buildModule("SplitCabinetEcosystem", (m) => {
  // Deployment parameters
  const platformFeeRecipient = m.getParameter("platformFeeRecipient");
  const adminAddress = m.getParameter("adminAddress");

  // Deploy base contracts first
  const { accessControl } = m.useModule(TuuKeepAccessControlModule);
  const { randomness } = m.useModule(RandomnessModule);

  // Deploy TuuKeepCabinetCore
  const { cabinetCore } = m.useModule(TuuKeepCabinetCoreModule, {
    parameters: {
      accessControlAddress: accessControl,
      platformFeeRecipient,
    },
  });

  // Deploy TuuCoin with cabinet integration
  const { tuuCoin } = m.useModule(TuuCoinModule, {
    parameters: {
      accessControlAddress: accessControl,
      cabinetContractAddress: cabinetCore,
    },
  });

  // Deploy TuuKeepCabinetGame
  const { cabinetGame } = m.useModule(TuuKeepCabinetGameModule, {
    parameters: {
      cabinetCoreAddress: cabinetCore,
      tuuCoinAddress: tuuCoin,
      randomnessAddress: randomness,
      platformFeeRecipient,
    },
  });

  // Set up Core-Game contract relationship
  m.call(cabinetCore, "setGameContract", [cabinetGame]);

  // Deploy Marketplace with new core contract
  const { marketplace } = m.useModule(TuuKeepMarketplaceModule, {
    parameters: {
      cabinetContractAddress: cabinetCore,
      accessControlAddress: accessControl,
      platformFeeRecipient,
    },
  });

  // Deploy TierSale with new core contract
  const { tierSale } = m.useModule(TuuKeepTierSaleModule, {
    parameters: {
      cabinetContractAddress: cabinetCore,
      platformTreasuryAddress: platformFeeRecipient,
    },
  });

  // Grant necessary roles
  m.call(accessControl, "grantRole", [
    m.staticCall(accessControl, "PLATFORM_ADMIN_ROLE"),
    adminAddress,
  ]);

  m.call(cabinetCore, "grantRole", [
    m.staticCall(cabinetCore, "MINTER_ROLE"),
    tierSale,
  ]);

  m.call(tuuCoin, "grantRole", [
    m.staticCall(tuuCoin, "CABINET_MINTER_ROLE"),
    cabinetGame,
  ]);

  return {
    accessControl,
    cabinetCore,
    cabinetGame,
    tuuCoin,
    randomness,
    marketplace,
    tierSale,
  };
});

export default SplitCabinetEcosystemModule;