import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const TuuKeepEcosystemModule = buildModule("TuuKeepEcosystem", (m) => {
  // Get deployer account
  const deployer = m.getAccount(0);

  // Phase 1: Foundation Contracts
  const accessControl = m.contract("TuuKeepAccessControl", []);

  const tuuCoin = m.contract("TuuCoin", [accessControl]);

  const randomness = m.contract("Randomness", []);

  // Phase 2: Core Cabinet System
  const cabinetCore = m.contract("TuuKeepCabinetCore", [
    accessControl,
    deployer, // Platform fee recipient
  ]);

  const cabinetGame = m.contract("TuuKeepCabinetGame", [
    cabinetCore,
    tuuCoin,
    randomness,
  ]);

  // Phase 3: Ecosystem Extensions
  const marketplace = m.contract("TuuKeepMarketplace", [
    cabinetCore,
    accessControl,
  ]);

  const tierSale = m.contract("TuuKeepTierSale", [cabinetCore]);

  return {
    accessControl,
    tuuCoin,
    randomness,
    cabinetCore,
    cabinetGame,
    marketplace,
    tierSale,
  };
});

export default TuuKeepEcosystemModule;