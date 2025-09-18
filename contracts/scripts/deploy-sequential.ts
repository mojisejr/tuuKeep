import { config } from "dotenv";
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";
import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

// ES module compatibility
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load environment variables
config();

interface DeploymentResult {
  name: string;
  address: string;
  transactionHash: string;
  gasUsed: string;
  blockNumber: string;
}

async function deployContract(contractName: string, args: string[] = []): Promise<DeploymentResult> {
  console.log(`\n📦 Deploying ${contractName}...`);

  try {
    // Create a simple deployment script for this contract
    const deployScript = `
      import hre from "hardhat";

      async function main() {
        const deployer = (await hre.viem.getWalletClients())[0];
        const publicClient = await hre.viem.getPublicClient();

        console.log("Deployer:", deployer.account.address);

        const args = ${JSON.stringify(args)};
        console.log("Args:", args);

        const contract = await hre.viem.deployContract("${contractName}", args);

        console.log("Address:", contract.address);
        console.log("Transaction hash:", contract.transactionHash);

        const receipt = await publicClient.getTransactionReceipt({ hash: contract.transactionHash });

        console.log("Gas used:", receipt.gasUsed.toString());
        console.log("Block number:", receipt.blockNumber.toString());

        return {
          name: "${contractName}",
          address: contract.address,
          transactionHash: contract.transactionHash,
          gasUsed: receipt.gasUsed.toString(),
          blockNumber: receipt.blockNumber.toString()
        };
      }

      main().then(result => {
        console.log("RESULT:", JSON.stringify(result));
        process.exit(0);
      }).catch(error => {
        console.error("ERROR:", error.message);
        process.exit(1);
      });
    `;

    // Write temporary script
    const tempScript = path.join(__dirname, `temp-deploy-${contractName}.ts`);
    fs.writeFileSync(tempScript, deployScript);

    // Execute deployment
    const { stdout, stderr } = await execAsync(`npx hardhat run ${tempScript} --network kubTestnet`);

    // Clean up temp script
    fs.unlinkSync(tempScript);

    // Parse result
    const resultMatch = stdout.match(/RESULT: (.+)/);
    if (resultMatch) {
      const result = JSON.parse(resultMatch[1]);
      console.log(`✅ ${contractName} deployed successfully!`);
      console.log(`📍 Address: ${result.address}`);
      console.log(`⛽ Gas used: ${result.gasUsed}`);
      return result;
    } else {
      throw new Error(`Failed to parse deployment result for ${contractName}`);
    }

  } catch (error) {
    console.error(`❌ Failed to deploy ${contractName}:`, error);
    throw error;
  }
}

async function main() {
  console.log('🚀 Starting Sequential KUB Testnet Deployment...\n');

  // Deployment tracking
  const deploymentResults: any = {
    network: 'kubTestnet',
    chainId: 25925,
    timestamp: new Date().toISOString(),
    contracts: {},
  };

  try {
    console.log('📋 Phase 1: Foundation Contracts');

    // 1. Deploy TuuKeepAccessControl
    const accessControl = await deployContract('TuuKeepAccessControl', []);
    deploymentResults.contracts.accessControl = accessControl.address;

    // 2. Deploy TuuCoin
    const tuuCoin = await deployContract('TuuCoin', [accessControl.address]);
    deploymentResults.contracts.tuuCoin = tuuCoin.address;

    // 3. Deploy Randomness
    const randomness = await deployContract('Randomness', []);
    deploymentResults.contracts.randomness = randomness.address;

    console.log('\n📋 Phase 2: Core Cabinet System');

    // 4. Deploy TuuKeepCabinetCore
    const cabinetCore = await deployContract('TuuKeepCabinetCore', [
      accessControl.address,
      '0x4C06524B1bd7AA002747252257bBE0C472735A6D' // Platform fee recipient
    ]);
    deploymentResults.contracts.cabinetCore = cabinetCore.address;

    // 5. Deploy TuuKeepCabinetGame
    const cabinetGame = await deployContract('TuuKeepCabinetGame', [
      cabinetCore.address,
      tuuCoin.address,
      randomness.address
    ]);
    deploymentResults.contracts.cabinetGame = cabinetGame.address;

    console.log('\n📋 Phase 3: Ecosystem Extensions');

    // 6. Deploy TuuKeepMarketplace
    const marketplace = await deployContract('TuuKeepMarketplace', [
      cabinetCore.address,
      accessControl.address
    ]);
    deploymentResults.contracts.marketplace = marketplace.address;

    // 7. Deploy TuuKeepTierSale
    const tierSale = await deployContract('TuuKeepTierSale', [cabinetCore.address]);
    deploymentResults.contracts.tierSale = tierSale.address;

    console.log('\n🎉 All contracts deployed successfully!');
    console.log('\n📊 Deployment Summary:');
    Object.entries(deploymentResults.contracts).forEach(([name, address]) => {
      console.log(`- ${name}: ${address}`);
    });

    // Save results
    const deploymentsDir = path.join(__dirname, '../deployments');
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }

    const resultFile = path.join(deploymentsDir, `kubTestnet-real-${Date.now()}.json`);
    fs.writeFileSync(resultFile, JSON.stringify(deploymentResults, null, 2));

    console.log(`\n💾 Results saved to: ${resultFile}`);
    console.log('\n🔍 Next steps:');
    console.log('1. Verify contracts on KubScan');
    console.log('2. Test cross-contract integration');
    console.log('3. Document gas costs and performance');

    return deploymentResults;

  } catch (error) {
    console.error('\n❌ Deployment failed:', error);
    throw error;
  }
}

// Run deployment
main()
  .then(() => {
    console.log('\n✅ Deployment completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Deployment failed:', error);
    process.exit(1);
  });