import hre from "hardhat";
import { formatEther } from "viem";
import { config } from "dotenv";
import * as fs from "fs";
import * as path from "path";

// Load environment variables
config();

async function main() {
  console.log("🚀 Starting KUB Testnet Deployment with Hardhat 3.0 + viem...\n");

  // Get the deployer account
  const [deployer] = await hre.viem.getWalletClients();
  console.log(`👤 Deployer: ${deployer.account.address}`);

  // Check balance
  const publicClient = await hre.viem.getPublicClient();
  const balance = await publicClient.getBalance({ address: deployer.account.address });
  console.log(`💰 Balance: ${formatEther(balance)} tKUB`);

  // Get network info
  const chainId = await publicClient.getChainId();
  console.log(`🌐 Chain ID: ${chainId}`);
  console.log(`📡 Network: kubTestnet\n`);

  // Deployment tracking
  const deploymentResults: any = {
    network: 'kubTestnet',
    chainId: chainId.toString(),
    timestamp: new Date().toISOString(),
    deployer: deployer.account.address,
    contracts: {},
  };

  try {
    console.log('📋 Phase 1: Foundation Contracts');

    // 1. Deploy TuuKeepAccessControl
    console.log('\n📦 Deploying TuuKeepAccessControl...');
    const accessControl = await hre.viem.deployContract("TuuKeepAccessControl", []);
    console.log(`✅ TuuKeepAccessControl deployed successfully!`);
    console.log(`📍 Address: ${accessControl.address}`);
    deploymentResults.contracts.accessControl = accessControl.address;

    // 2. Deploy TuuCoin
    console.log('\n📦 Deploying TuuCoin...');
    const tuuCoin = await hre.viem.deployContract("TuuCoin", [accessControl.address]);
    console.log(`✅ TuuCoin deployed successfully!`);
    console.log(`📍 Address: ${tuuCoin.address}`);
    deploymentResults.contracts.tuuCoin = tuuCoin.address;

    // 3. Deploy Randomness
    console.log('\n📦 Deploying Randomness...');
    const randomness = await hre.viem.deployContract("Randomness", []);
    console.log(`✅ Randomness deployed successfully!`);
    console.log(`📍 Address: ${randomness.address}`);
    deploymentResults.contracts.randomness = randomness.address;

    console.log('\n📋 Phase 2: Core Cabinet System');

    // 4. Deploy TuuKeepCabinetCore
    console.log('\n📦 Deploying TuuKeepCabinetCore...');
    const cabinetCore = await hre.viem.deployContract("TuuKeepCabinetCore", [
      accessControl.address,
      deployer.account.address // Platform fee recipient
    ]);
    console.log(`✅ TuuKeepCabinetCore deployed successfully!`);
    console.log(`📍 Address: ${cabinetCore.address}`);
    deploymentResults.contracts.cabinetCore = cabinetCore.address;

    // 5. Deploy TuuKeepCabinetGame
    console.log('\n📦 Deploying TuuKeepCabinetGame...');
    const cabinetGame = await hre.viem.deployContract("TuuKeepCabinetGame", [
      cabinetCore.address,
      tuuCoin.address,
      randomness.address
    ]);
    console.log(`✅ TuuKeepCabinetGame deployed successfully!`);
    console.log(`📍 Address: ${cabinetGame.address}`);
    deploymentResults.contracts.cabinetGame = cabinetGame.address;

    console.log('\n📋 Phase 3: Ecosystem Extensions');

    // 6. Deploy TuuKeepMarketplace
    console.log('\n📦 Deploying TuuKeepMarketplace...');
    const marketplace = await hre.viem.deployContract("TuuKeepMarketplace", [
      cabinetCore.address,
      accessControl.address
    ]);
    console.log(`✅ TuuKeepMarketplace deployed successfully!`);
    console.log(`📍 Address: ${marketplace.address}`);
    deploymentResults.contracts.marketplace = marketplace.address;

    // 7. Deploy TuuKeepTierSale
    console.log('\n📦 Deploying TuuKeepTierSale...');
    const tierSale = await hre.viem.deployContract("TuuKeepTierSale", [cabinetCore.address]);
    console.log(`✅ TuuKeepTierSale deployed successfully!`);
    console.log(`📍 Address: ${tierSale.address}`);
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
    console.log('1. Verify contracts:');
    Object.entries(deploymentResults.contracts).forEach(([name, address]) => {
      console.log(`   npx hardhat verify --network kubTestnet ${address}`);
    });
    console.log('\n2. View on block explorer:');
    console.log('   https://testnet.kubscan.com/');

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