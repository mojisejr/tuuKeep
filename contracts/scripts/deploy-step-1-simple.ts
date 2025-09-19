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
    const { abi, bytecode } = await loadContractArtifact(contractName);

    // Deploy with explicit gas settings for KUB testnet
    const hash = await walletClient.deployContract({
      abi,
      bytecode: bytecode as `0x${string}`,
      args: constructorArgs,
      gas: 6000000n, // Explicit gas limit
    });

    console.log(`⏳ Transaction hash: ${hash}`);
    const receipt = await publicClient.waitForTransactionReceipt({ hash });

    console.log(`✅ ${contractName} deployed successfully!`);
    console.log(`📍 Address: ${receipt.contractAddress}`);
    console.log(`⛽ Gas used: ${receipt.gasUsed.toString()}`);

    return {
      address: receipt.contractAddress,
      transactionHash: hash,
      gasUsed: receipt.gasUsed,
    };
  } catch (error) {
    console.error(`❌ Failed to deploy ${contractName}:`, error);
    throw error;
  }
}

async function main() {
  console.log('🚀 Starting Step 1: Foundation Contracts Deployment (Simplified)');
  console.log('================================================================');

  // Create account and clients
  const privateKey = process.env.KUB_TESTNET_PRIVATE_KEY;
  if (!privateKey) {
    throw new Error('KUB_TESTNET_PRIVATE_KEY not set in environment variables');
  }

  const account = privateKeyToAccount(privateKey.startsWith('0x') ? privateKey as `0x${string}` : `0x${privateKey}` as `0x${string}`);

  const walletClient = createWalletClient({
    account,
    chain: kubTestnet,
    transport: http(),
  });

  const publicClient = createPublicClient({
    chain: kubTestnet,
    transport: http(),
  });

  console.log(`Deployer: ${account.address}`);
  console.log(`Balance: ${formatEther(await publicClient.getBalance({ address: account.address }))} KUB`);

  const deployedContracts: { [key: string]: string } = {};

  try {
    // 1. Deploy TuuKeepAccessControl
    const accessControlResult = await deployContract(walletClient, publicClient, 'TuuKeepAccessControl');
    deployedContracts.TuuKeepAccessControl = accessControlResult.address!;

    // 2. Deploy TuuCoinBase
    const tuuCoinBaseResult = await deployContract(walletClient, publicClient, 'TuuCoinBase', [
      accessControlResult.address,
      account.address
    ]);
    deployedContracts.TuuCoinBase = tuuCoinBaseResult.address!;

    // 3. Deploy Randomness
    const randomnessResult = await deployContract(walletClient, publicClient, 'Randomness');
    deployedContracts.Randomness = randomnessResult.address!;

    // Save deployment data
    const deploymentData = {
      network: "kub-testnet",
      timestamp: new Date().toISOString(),
      step: "1-foundation",
      contracts: deployedContracts,
      deployer: account.address,
    };

    const deploymentDir = path.join(__dirname, '..', 'deployments');
    if (!fs.existsSync(deploymentDir)) {
      fs.mkdirSync(deploymentDir, { recursive: true });
    }

    const deploymentFile = path.join(deploymentDir, 'step-1-foundation.json');
    fs.writeFileSync(deploymentFile, JSON.stringify(deploymentData, null, 2));

    console.log('\n🎉 Step 1 Foundation Deployment Complete!');
    console.log('==========================================');
    console.log('Deployed Contracts:');
    Object.entries(deployedContracts).forEach(([name, address]) => {
      console.log(`  ${name}: ${address}`);
    });
    console.log(`\n📁 Deployment data saved to: ${deploymentFile}`);

  } catch (error) {
    console.error('\n❌ Step 1 Deployment Failed:', error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });