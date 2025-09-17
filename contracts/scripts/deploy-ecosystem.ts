import { network } from "hardhat";
import { execSync } from "child_process";
import * as fs from "fs";
import * as path from "path";

/**
 * TuuKeep Ecosystem Deployment Script
 *
 * Deploys the complete TuuKeep ecosystem using Hardhat Ignition
 * and saves deployment addresses for verification and frontend integration
 *
 * Usage:
 * npx hardhat run scripts/deploy-ecosystem.ts --network kubTestnet
 * npx hardhat run scripts/deploy-ecosystem.ts --network kubMainnet
 */

interface DeploymentConfig {
  defaultAdmin: string;
  platformTreasury: string;
  platformFeeRecipient: string;
}

interface DeploymentResult {
  network: string;
  chainId: number;
  timestamp: string;
  contracts: {
    accessControl: string;
    tuuCoin: string;
    randomness: string;
    cabinet: string;
    marketplace: string;
    tierSale: string;
  };
  parameters: DeploymentConfig;
  transactions: {
    [contractName: string]: string;
  };
}

async function main() {
  console.log(`🚀 Starting TuuKeep ecosystem deployment on ${network.name}...`);

  // Get deployment configuration
  const config: DeploymentConfig = {
    defaultAdmin: process.env.DEFAULT_ADMIN || "",
    platformTreasury: process.env.PLATFORM_TREASURY || "",
    platformFeeRecipient: process.env.PLATFORM_FEE_RECIPIENT || "",
  };

  // Validate configuration
  if (!config.defaultAdmin || !config.platformTreasury || !config.platformFeeRecipient) {
    console.error("❌ Missing required environment variables:");
    console.log("- DEFAULT_ADMIN: Address that will receive admin roles");
    console.log("- PLATFORM_TREASURY: Address for platform revenue collection");
    console.log("- PLATFORM_FEE_RECIPIENT: Address for platform fee collection");
    return;
  }

  console.log("📋 Deployment Configuration:");
  console.log(`- Network: ${network.name}`);
  console.log(`- Default Admin: ${config.defaultAdmin}`);
  console.log(`- Platform Treasury: ${config.platformTreasury}`);
  console.log(`- Platform Fee Recipient: ${config.platformFeeRecipient}`);

  // Prepare deployment parameters
  const deploymentParams = JSON.stringify({
    defaultAdmin: config.defaultAdmin,
    platformTreasury: config.platformTreasury,
    platformFeeRecipient: config.platformFeeRecipient,
  });

  try {
    console.log("\n🔄 Deploying complete ecosystem...");

    // Deploy using Hardhat Ignition
    const deploymentCommand = `npx hardhat ignition deploy ignition/modules/FullEcosystem.ts --network ${network.name} --parameters '${deploymentParams}'`;

    console.log("📞 Running deployment command:");
    console.log(deploymentCommand);

    const deploymentOutput = execSync(deploymentCommand, {
      encoding: "utf-8",
      cwd: process.cwd(),
    });

    console.log("📝 Deployment output:");
    console.log(deploymentOutput);

    // Parse deployment results
    const deploymentResult = parseDeploymentOutput(deploymentOutput, config);

    // Save deployment results
    await saveDeploymentResults(deploymentResult);

    console.log("\n✅ Deployment completed successfully!");
    console.log("📁 Deployment results saved to deployments/ directory");
    console.log("\n🔍 Next steps:");
    console.log("1. Run contract verification:");
    console.log(`   npx hardhat run scripts/verify-ecosystem.ts --network ${network.name}`);
    console.log("2. Run post-deployment validation:");
    console.log(`   npx hardhat run scripts/validate-deployment.ts --network ${network.name}`);
    console.log("3. Update frontend configuration with new contract addresses");

  } catch (error) {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  }
}

function parseDeploymentOutput(output: string, config: DeploymentConfig): DeploymentResult {
  // TODO: Parse actual deployment output from Hardhat Ignition
  // This is a placeholder implementation
  console.log("📊 Parsing deployment output...");

  const result: DeploymentResult = {
    network: network.name,
    chainId: network.config.chainId || 0,
    timestamp: new Date().toISOString(),
    contracts: {
      accessControl: "0x...", // Will be parsed from actual output
      tuuCoin: "0x...",
      randomness: "0x...",
      cabinet: "0x...",
      marketplace: "0x...",
      tierSale: "0x...",
    },
    parameters: config,
    transactions: {},
  };

  // Parse contract addresses from ignition output
  // The actual implementation would parse the JSON output from Ignition

  return result;
}

async function saveDeploymentResults(result: DeploymentResult) {
  const deploymentsDir = path.join(process.cwd(), "deployments");

  // Create deployments directory if it doesn't exist
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  // Save deployment result
  const filename = `${result.network}-${Date.now()}.json`;
  const filepath = path.join(deploymentsDir, filename);

  fs.writeFileSync(filepath, JSON.stringify(result, null, 2));

  // Save latest deployment for the network
  const latestFilepath = path.join(deploymentsDir, `${result.network}-latest.json`);
  fs.writeFileSync(latestFilepath, JSON.stringify(result, null, 2));

  // Create environment file for verification
  const envContent = `
# TuuKeep Ecosystem Deployment - ${result.network}
# Generated on ${result.timestamp}

ACCESS_CONTROL_ADDRESS=${result.contracts.accessControl}
TUUCOIN_ADDRESS=${result.contracts.tuuCoin}
RANDOMNESS_ADDRESS=${result.contracts.randomness}
CABINET_ADDRESS=${result.contracts.cabinet}
MARKETPLACE_ADDRESS=${result.contracts.marketplace}
TIER_SALE_ADDRESS=${result.contracts.tierSale}

DEFAULT_ADMIN=${result.parameters.defaultAdmin}
PLATFORM_TREASURY=${result.parameters.platformTreasury}
PLATFORM_FEE_RECIPIENT=${result.parameters.platformFeeRecipient}
`;

  const envFilepath = path.join(deploymentsDir, `${result.network}.env`);
  fs.writeFileSync(envFilepath, envContent.trim());

  console.log(`💾 Deployment results saved to ${filename}`);
  console.log(`💾 Environment variables saved to ${result.network}.env`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment script failed:", error);
    process.exit(1);
  });