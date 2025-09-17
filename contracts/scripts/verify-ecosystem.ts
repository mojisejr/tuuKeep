import { network, run } from "hardhat";

/**
 * TuuKeep Ecosystem Contract Verification Script
 *
 * Verifies all deployed contracts on KubScan (testnet/mainnet)
 * Usage: npx hardhat run scripts/verify-ecosystem.ts --network kubTestnet
 */

interface ContractAddresses {
  accessControl: string;
  tuuCoin: string;
  randomness: string;
  cabinet: string;
  marketplace: string;
  tierSale: string;
}

interface DeploymentParameters {
  defaultAdmin: string;
  platformTreasury: string;
  platformFeeRecipient: string;
}

async function verifyContract(
  contractAddress: string,
  constructorArgs: any[],
  contractName: string
) {
  console.log(`\n🔍 Verifying ${contractName} at ${contractAddress}...`);

  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: constructorArgs,
    });
    console.log(`✅ ${contractName} verified successfully`);
  } catch (error) {
    if (error.toString().includes("Already Verified")) {
      console.log(`✅ ${contractName} already verified`);
    } else {
      console.error(`❌ Failed to verify ${contractName}:`, error);
    }
  }
}

async function main() {
  console.log(`🚀 Starting verification on ${network.name}...`);

  // TODO: Update these addresses after deployment
  const contractAddresses: ContractAddresses = {
    accessControl: process.env.ACCESS_CONTROL_ADDRESS || "",
    tuuCoin: process.env.TUUCOIN_ADDRESS || "",
    randomness: process.env.RANDOMNESS_ADDRESS || "",
    cabinet: process.env.CABINET_ADDRESS || "",
    marketplace: process.env.MARKETPLACE_ADDRESS || "",
    tierSale: process.env.TIER_SALE_ADDRESS || "",
  };

  const deploymentParams: DeploymentParameters = {
    defaultAdmin: process.env.DEFAULT_ADMIN || "",
    platformTreasury: process.env.PLATFORM_TREASURY || "",
    platformFeeRecipient: process.env.PLATFORM_FEE_RECIPIENT || "",
  };

  // Validate addresses
  const addresses = Object.values(contractAddresses);
  const params = Object.values(deploymentParams);

  if (addresses.some(addr => !addr) || params.some(param => !param)) {
    console.error("❌ Missing required addresses or parameters");
    console.log("Required environment variables:");
    console.log("- ACCESS_CONTROL_ADDRESS");
    console.log("- TUUCOIN_ADDRESS");
    console.log("- RANDOMNESS_ADDRESS");
    console.log("- CABINET_ADDRESS");
    console.log("- MARKETPLACE_ADDRESS");
    console.log("- TIER_SALE_ADDRESS");
    console.log("- DEFAULT_ADMIN");
    console.log("- PLATFORM_TREASURY");
    console.log("- PLATFORM_FEE_RECIPIENT");
    return;
  }

  // Verify contracts in dependency order
  console.log("📋 Verification Plan:");
  console.log("1. TuuKeepAccessControl");
  console.log("2. TuuCoin");
  console.log("3. Randomness");
  console.log("4. TuuKeepCabinet");
  console.log("5. TuuKeepMarketplace");
  console.log("6. TuuKeepTierSale");

  // 1. Verify TuuKeepAccessControl
  await verifyContract(
    contractAddresses.accessControl,
    [deploymentParams.defaultAdmin],
    "TuuKeepAccessControl"
  );

  // 2. Verify TuuCoin
  await verifyContract(
    contractAddresses.tuuCoin,
    [contractAddresses.accessControl, deploymentParams.defaultAdmin],
    "TuuCoin"
  );

  // 3. Verify Randomness
  await verifyContract(
    contractAddresses.randomness,
    [deploymentParams.defaultAdmin],
    "Randomness"
  );

  // 4. Verify TuuKeepCabinet
  await verifyContract(
    contractAddresses.cabinet,
    [
      contractAddresses.accessControl,
      contractAddresses.tuuCoin,
      contractAddresses.randomness,
      deploymentParams.platformFeeRecipient,
    ],
    "TuuKeepCabinet"
  );

  // 5. Verify TuuKeepMarketplace
  await verifyContract(
    contractAddresses.marketplace,
    [
      contractAddresses.cabinet,
      contractAddresses.accessControl,
      deploymentParams.platformFeeRecipient,
    ],
    "TuuKeepMarketplace"
  );

  // 6. Verify TuuKeepTierSale
  await verifyContract(
    contractAddresses.tierSale,
    [
      contractAddresses.cabinet,
      deploymentParams.platformTreasury,
      deploymentParams.defaultAdmin,
    ],
    "TuuKeepTierSale"
  );

  console.log("\n🎉 Verification process completed!");
  console.log(`📱 View contracts on KubScan: ${getKubScanUrl()}`);
}

function getKubScanUrl(): string {
  switch (network.name) {
    case "kubTestnet":
      return "https://testnet.kubscan.io";
    case "kubMainnet":
      return "https://kubscan.io";
    default:
      return "Unknown network";
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Verification failed:", error);
    process.exit(1);
  });