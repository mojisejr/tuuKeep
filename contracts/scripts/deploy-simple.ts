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
  console.log(`📦 Deploying ${contractName}...`);

  try {
    // Load contract artifact
    const { abi, bytecode } = await loadContractArtifact(contractName);

    // Check if bytecode is valid
    if (!bytecode || bytecode === '0x') {
      throw new Error(`Invalid bytecode for ${contractName}`);
    }

    console.log(`  📋 Constructor args: [${constructorArgs.join(', ')}]`);

    // Deploy contract
    const hash = await walletClient.deployContract({
      abi,
      bytecode: bytecode as `0x${string}`,
      args: constructorArgs,
    });

    console.log(`  ⏳ Transaction hash: ${hash}`);

    // Wait for transaction receipt
    const receipt = await publicClient.waitForTransactionReceipt({ hash });

    if (!receipt.contractAddress) {
      throw new Error(`No contract address in receipt for ${contractName}`);
    }

    console.log(`  ✅ ${contractName} deployed successfully!`);
    console.log(`  📍 Address: ${receipt.contractAddress}`);
    console.log(`  ⛽ Gas used: ${receipt.gasUsed.toString()}`);

    return {
      address: receipt.contractAddress,
      transactionHash: hash,
      gasUsed: receipt.gasUsed,
      blockNumber: receipt.blockNumber,
    };
  } catch (error) {
    console.error(`  ❌ Failed to deploy ${contractName}:`, error);
    throw error;
  }
}

async function main() {
  console.log('🚀 Starting Simple KUB Testnet Deployment...\n');

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

  let totalGasUsed = 0n;

  try {
    console.log('📋 Phase 1: Foundation Contracts\n');

    // Only deploy essential contracts first to avoid complexity
    const accessControl = await deployContract(walletClient, publicClient, 'TuuKeepAccessControl', []);
    deploymentResults.contracts.accessControl = accessControl.address;
    totalGasUsed += accessControl.gasUsed;

    const tuuCoin = await deployContract(walletClient, publicClient, 'TuuCoin', [accessControl.address]);
    deploymentResults.contracts.tuuCoin = tuuCoin.address;
    totalGasUsed += tuuCoin.gasUsed;

    const randomness = await deployContract(walletClient, publicClient, 'Randomness', []);
    deploymentResults.contracts.randomness = randomness.address;
    totalGasUsed += randomness.gasUsed;

    console.log('\n📋 Phase 2: Core Cabinet System\n');

    const cabinetCore = await deployContract(walletClient, publicClient, 'TuuKeepCabinetCore', [
      accessControl.address,
      account.address // Platform fee recipient
    ]);
    deploymentResults.contracts.cabinetCore = cabinetCore.address;
    totalGasUsed += cabinetCore.gasUsed;

    console.log('\n🎉 Core contracts deployed successfully!');
    console.log('\n📊 Deployment Summary:');
    Object.entries(deploymentResults.contracts).forEach(([name, address]) => {
      console.log(`- ${name}: ${address}`);
    });

    console.log(`\n⛽ Total Gas Used: ${totalGasUsed.toString()}`);
    const gasCost = totalGasUsed * 1000000000n; // Estimate 1 gwei gas price
    console.log(`💰 Estimated Cost: ${formatEther(gasCost)} tKUB`);

    // Save results
    const deploymentsDir = path.join(__dirname, '../deployments');
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }

    const resultFile = path.join(deploymentsDir, `kubTestnet-partial-${Date.now()}.json`);
    fs.writeFileSync(resultFile, JSON.stringify(deploymentResults, null, 2));

    console.log(`\n💾 Results saved to: ${resultFile}`);

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