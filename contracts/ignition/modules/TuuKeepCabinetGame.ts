import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const TuuKeepCabinetGameModule = buildModule("TuuKeepCabinetGame", (m) => {
  // Parameters for deployment
  const cabinetCoreAddress = m.getParameter("cabinetCoreAddress");
  const tuuCoinAddress = m.getParameter("tuuCoinAddress");
  const randomnessAddress = m.getParameter("randomnessAddress");
  const platformFeeRecipient = m.getParameter("platformFeeRecipient");

  // Deploy TuuKeepCabinetGame
  const cabinetGame = m.contract("TuuKeepCabinetGame", [
    cabinetCoreAddress,
    tuuCoinAddress,
    randomnessAddress,
    platformFeeRecipient,
  ]);

  return { cabinetGame };
});

export default TuuKeepCabinetGameModule;