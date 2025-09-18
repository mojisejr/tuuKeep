import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const TuuKeepCabinetCoreModule = buildModule("TuuKeepCabinetCore", (m) => {
  // Parameters for deployment
  const name = m.getParameter("name", "TuuKeep Cabinet");
  const symbol = m.getParameter("symbol", "TKC");
  const accessControlAddress = m.getParameter("accessControlAddress");
  const platformFeeRecipient = m.getParameter("platformFeeRecipient");

  // Deploy TuuKeepCabinetCore
  const cabinetCore = m.contract("TuuKeepCabinetCore", [
    name,
    symbol,
    accessControlAddress,
    platformFeeRecipient,
  ]);

  return { cabinetCore };
});

export default TuuKeepCabinetCoreModule;