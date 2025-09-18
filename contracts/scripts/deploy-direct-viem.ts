import { createWalletClient, createPublicClient, http, formatEther } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { config } from 'dotenv';
import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';

// ES module compatibility
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load environment variables
config();

// KUB Testnet chain configuration
const kubTestnet = {
  id: 25925,
  name: 'KUB Testnet',
  nativeCurrency: { name: 'tKUB', symbol: 'tKUB', decimals: 18 },
  rpcUrls: {
    default: { http: ['https://rpc-testnet.bitkubchain.io'] },
  },
  blockExplorers: {
    default: { name: 'KubScan Testnet', url: 'https://testnet.kubscan.com' },
  },
};

async function loadContractArtifact(contractName: string) {
  // Try multiple possible paths for contract artifacts
  const possiblePaths = [
    path.join(__dirname, `../artifacts/contracts/${contractName}.sol/${contractName}.json`),
    path.join(__dirname, `../artifacts/contracts/Utils/Security/${contractName}.sol/${contractName}.json`),
    path.join(__dirname, `../artifacts/contracts/Utils/${contractName}.sol/${contractName}.json`),
  ];

  for (const artifactPath of possiblePaths) {
    if (fs.existsSync(artifactPath)) {
      const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf-8'));
      return {
        abi: artifact.abi,
        bytecode: artifact.bytecode,
      };
    }
  }

  throw new Error(`Contract artifact not found: ${contractName}`);
}

async function deployContract(
  walletClient: any,
  publicClient: any,
  contractName: string,
  constructorArgs: any[] = []
) {
  console.log(`\n📦 Deploying ${contractName}...`);

  try {
    // Load contract artifact
    const { abi, bytecode } = await loadContractArtifact(contractName);

    // Deploy contract
    const hash = await walletClient.deployContract({
      abi,
      bytecode: bytecode as `0x${string}`,
      args: constructorArgs,
    });

    console.log(`⏳ Transaction hash: ${hash}`);

    // Wait for transaction receipt
    const receipt = await publicClient.waitForTransactionReceipt({ hash });

    console.log(`✅ ${contractName} deployed successfully!`);
    console.log(`📍 Address: ${receipt.contractAddress}`);
    console.log(`⛽ Gas used: ${receipt.gasUsed.toString()}`);
    console.log(`📦 Block number: ${receipt.blockNumber.toString()}`);

    return {
      address: receipt.contractAddress,
      transactionHash: hash,
      gasUsed: receipt.gasUsed,
      blockNumber: receipt.blockNumber,
    };
  } catch (error) {
    console.error(`❌ Failed to deploy ${contractName}:`, error);
    throw error;
  }
}

async function main() {
  console.log('🚀 Starting Direct Viem KUB Testnet Deployment...\n');

  // Validate environment
  const privateKey = process.env.KUB_TESTNET_PRIVATE_KEY;
  if (!privateKey) {
    throw new Error('KUB_TESTNET_PRIVATE_KEY not set in environment variables');
  }

  // Create account and clients
  const account = privateKeyToAccount(privateKey.startsWith('0x') ? privateKey as `0x${string}` : `0x${privateKey}` as `0x${string}`);

  const publicClient = createPublicClient({
    chain: kubTestnet,
    transport: http('https://rpc-testnet.bitkubchain.io'),
  });

  const walletClient = createWalletClient({
    account,
    chain: kubTestnet,
    transport: http('https://rpc-testnet.bitkubchain.io'),
  });

  // Display account info
  console.log(`👤 Deployer: ${account.address}`);
  const balance = await publicClient.getBalance({ address: account.address });
  console.log(`💰 Balance: ${formatEther(balance)} tKUB`);

  const chainId = await publicClient.getChainId();
  console.log(`🌐 Chain ID: ${chainId}`);
  console.log(`📡 RPC: https://rpc-testnet.bitkubchain.io\n`);

  // Deployment tracking
  const deploymentResults: any = {
    network: 'kubTestnet',
    chainId,
    timestamp: new Date().toISOString(),
    deployer: account.address,
    contracts: {},
  };

  try {
    console.log('📋 Phase 1: Foundation Contracts');

    // 1. Deploy TuuKeepAccessControl
    const accessControl = await deployContract(
      walletClient,
      publicClient,
      'TuuKeepAccessControl',
      [] // No constructor arguments
    );
    deploymentResults.contracts.accessControl = accessControl.address;

    // 2. Deploy TuuCoin
    const tuuCoin = await deployContract(
      walletClient,
      publicClient,
      'TuuCoin',
      [accessControl.address]
    );
    deploymentResults.contracts.tuuCoin = tuuCoin.address;

    // 3. Deploy Randomness
    const randomness = await deployContract(
      walletClient,
      publicClient,
      'Randomness',
      []
    );
    deploymentResults.contracts.randomness = randomness.address;

    console.log('\n📋 Phase 2: Core Cabinet System');

    // 4. Deploy TuuKeepCabinetCore
    const cabinetCore = await deployContract(
      walletClient,
      publicClient,
      'TuuKeepCabinetCore',
      [
        accessControl.address,
        account.address, // Platform fee recipient
      ]
    );
    deploymentResults.contracts.cabinetCore = cabinetCore.address;

    // 5. Deploy TuuKeepCabinetGame
    const cabinetGame = await deployContract(
      walletClient,
      publicClient,
      'TuuKeepCabinetGame',
      [
        cabinetCore.address,
        tuuCoin.address,
        randomness.address,
      ]
    );
    deploymentResults.contracts.cabinetGame = cabinetGame.address;

    console.log('\n📋 Phase 3: Ecosystem Extensions');

    // 6. Deploy TuuKeepMarketplace
    const marketplace = await deployContract(
      walletClient,
      publicClient,
      'TuuKeepMarketplace',
      [
        cabinetCore.address,
        accessControl.address,
      ]
    );
    deploymentResults.contracts.marketplace = marketplace.address;

    // 7. Deploy TuuKeepTierSale
    const tierSale = await deployContract(
      walletClient,
      publicClient,
      'TuuKeepTierSale',
      [cabinetCore.address]
    );
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