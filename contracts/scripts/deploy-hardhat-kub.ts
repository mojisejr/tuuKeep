import { network } from "hardhat";
import { config } from "dotenv";
import * as fs from "fs";
import * as path from "path";
import { formatEther } from "viem";

// Load environment variables
config();

interface DeploymentResult {
  network: string;
  chainId: number;
  timestamp: string;
  deployer: string;
  contracts: {
    accessControl?: string;
    tuuCoin?: string;
    randomness?: string;
    cabinetCore?: string;
    cabinetGame?: string;
    marketplace?: string;
    tierSale?: string;
  };
  gasUsed: {
    [contractName: string]: string;
  };
  blockNumbers: {
    [contractName: string]: number;
  };
  transactionHashes: {
    [contractName: string]: string;
  };
}

async function deployContract(
  viem: any,
  contractName: string,
  args: any[] = [],
  result: DeploymentResult
) {
  console.log(`📦 Deploying ${contractName}...`);

  try {
    // Deploy the contract using viem
    const contract = await viem.deployContract(contractName, args);

    console.log(`✅ ${contractName} deployed at: ${contract.address}`);
    console.log(`⛽ Gas used: ${contract.receipt?.gasUsed?.toString() || 'N/A'}`);
    console.log(`📦 Block number: ${contract.receipt?.blockNumber?.toString() || 'N/A'}`);
    console.log(`⏳ Transaction hash: ${contract.receipt?.transactionHash || 'N/A'}`);

    // Store results
    result.contracts[contractName as keyof typeof result.contracts] = contract.address;
    if (contract.receipt) {
      result.gasUsed[contractName] = contract.receipt.gasUsed?.toString() || '0';
      result.blockNumbers[contractName] = Number(contract.receipt.blockNumber || 0);
      result.transactionHashes[contractName] = contract.receipt.transactionHash || '';
    }

    return contract;
  } catch (error) {
    console.error(`❌ Failed to deploy ${contractName}:`, error);
    throw error;
  }
}

async function setContractRoles(contracts: any, result: DeploymentResult) {
  console.log('🔑 Configuring contract roles and relationships...');

  try {
    if (contracts.cabinetCore && contracts.cabinetGame) {
      console.log('🔗 Setting Game contract in Core contract...');
      const tx = await contracts.cabinetCore.write.setGameContract([contracts.cabinetGame.address]);
      // In viem, we wait for transaction receipt differently
      console.log('✅ Game contract set in Core contract');
    }

    // Additional role configurations can be added here

    console.log('✅ Contract roles configured successfully');
  } catch (error) {
    console.error('❌ Failed to configure roles:', error);
    throw error;
  }
}

async function main() {
  console.log('🚀 Starting Hardhat-based KUB testnet deployment...');

  // Connect to network and get viem clients
  const { viem } = await network.connect();
  const accounts = await viem.getWalletClients();
  const publicClient = await viem.getPublicClient();
  const deployer = accounts[0];

  const deployerAddress = deployer.account.address;

  // Initialize deployment result
  const deploymentResult: DeploymentResult = {
    network: 'kubTestnet',
    chainId: await publicClient.getChainId(),
    timestamp: new Date().toISOString(),
    deployer: deployerAddress,
    contracts: {},
    gasUsed: {},
    blockNumbers: {},
    transactionHashes: {},
  };

  console.log(`👤 Deployer: ${deployerAddress}`);
  const balance = await publicClient.getBalance({ address: deployerAddress });
  console.log(`💰 Balance: ${formatEther(balance)} tKUB`);
  console.log(`🌐 Chain ID: ${deploymentResult.chainId}`);

  const contracts: any = {};

  try {
    console.log('\n📋 Phase 1: Foundation Contracts');

    // 1. Deploy TuuKeepAccessControl
    contracts.accessControl = await deployContract(
      viem,
      'TuuKeepAccessControl',
      [],
      deploymentResult
    );

    // 2. Deploy TuuCoin
    contracts.tuuCoin = await deployContract(
      viem,
      'TuuCoin',
      [contracts.accessControl.address],
      deploymentResult
    );

    // 3. Deploy Randomness
    contracts.randomness = await deployContract(
      viem,
      'Randomness',
      [],
      deploymentResult
    );

    console.log('\n📋 Phase 2: Core Cabinet System');

    // 4. Deploy TuuKeepCabinetCore
    contracts.cabinetCore = await deployContract(
      viem,
      'TuuKeepCabinetCore',
      [
        contracts.accessControl.address,
        deployerAddress, // Platform fee recipient
      ],
      deploymentResult
    );

    // 5. Deploy TuuKeepCabinetGame
    contracts.cabinetGame = await deployContract(
      viem,
      'TuuKeepCabinetGame',
      [
        contracts.cabinetCore.address,
        contracts.tuuCoin.address,
        contracts.randomness.address,
      ],
      deploymentResult
    );

    console.log('\n📋 Phase 3: Ecosystem Extensions');

    // 6. Deploy TuuKeepMarketplace
    contracts.marketplace = await deployContract(
      viem,
      'TuuKeepMarketplace',
      [
        contracts.cabinetCore.address,
        contracts.accessControl.address,
      ],
      deploymentResult
    );

    // 7. Deploy TuuKeepTierSale
    contracts.tierSale = await deployContract(
      viem,
      'TuuKeepTierSale',
      [contracts.cabinetCore.address],
      deploymentResult
    );

    console.log('\n📋 Phase 4: Contract Configuration');

    // Configure contract relationships and roles
    await setContractRoles(contracts, deploymentResult);

    // Calculate total gas used
    const totalGasUsed = Object.values(deploymentResult.gasUsed)
      .reduce((total, gas) => total + BigInt(gas), BigInt(0));

    console.log('\n🎉 Deployment completed successfully!');
    console.log('📊 Summary:');
    console.log(`- Total contracts deployed: ${Object.keys(deploymentResult.contracts).length}`);
    console.log(`- Total gas used: ${totalGasUsed.toString()}`);
    console.log(`- Deployment cost: ~${parseFloat((Number(totalGasUsed) * 1e-9).toFixed(6))} tKUB`);

    // Save deployment results
    const deploymentsDir = path.join(__dirname, '../deployments');
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }

    const resultFile = path.join(deploymentsDir, `kubTestnet-${Date.now()}.json`);
    fs.writeFileSync(resultFile, JSON.stringify(deploymentResult, null, 2));

    console.log(`📁 Deployment results saved to: ${resultFile}`);
    console.log('\n🔍 Next steps:');
    console.log('1. Verify contracts on KubScan:');
    console.log('   npx hardhat verify --network kubTestnet <CONTRACT_ADDRESS>');
    console.log('2. Run integration tests:');
    console.log('   npx hardhat run scripts/validate-deployment.ts --network kubTestnet');

    return deploymentResult;

  } catch (error) {
    console.error('❌ Deployment failed:', error);
    throw error;
  }
}

// Run deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });