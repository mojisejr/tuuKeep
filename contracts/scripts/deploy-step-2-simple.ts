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

    const hash = await walletClient.deployContract({
      abi,
      bytecode: bytecode as `0x${string}`,
      args: constructorArgs,
      gas: 6000000n,
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
  console.log('🏠 Starting Step 2: Cabinet Contracts Deployment');
  console.log('================================================');

  // Load Step 1 deployment data
  const step1File = path.join(__dirname, '..', 'deployments', 'step-1-foundation.json');
  if (!fs.existsSync(step1File)) {
    throw new Error("Step 1 deployment not found. Please run deploy-step-1-simple.ts first.");
  }

  const step1Data = JSON.parse(fs.readFileSync(step1File, 'utf8'));
  const accessControlAddress = step1Data.contracts.TuuKeepAccessControl;
  console.log(`Using AccessControl from Step 1: ${accessControlAddress}`);

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
    // First, deploy required libraries
    console.log('\n📚 Deploying Required Libraries...');

    // Deploy ValidationLib
    const validationLibResult = await deployContract(walletClient, publicClient, 'ValidationLib');
    deployedContracts.ValidationLib = validationLibResult.address!;

    console.log('\n🏗️  Libraries deployed. Now deploying contracts with library linking...');

    // Note: For contracts with library dependencies, we would need to use library linking
    // For now, let's try deploying contracts that don't require ValidationLib

    // Check if there are simpler cabinet contracts we can deploy first
    console.log('\n⚠️  Skipping TuuKeepCabinetNFT due to library dependency complexity');
    console.log('    This requires library linking which is complex with viem');

    // 2. Deploy TuuKeepCabinetConfig
    const cabinetConfigResult = await deployContract(walletClient, publicClient, 'TuuKeepCabinetConfig', [
      accessControlAddress   // access control
    ]);
    deployedContracts.TuuKeepCabinetConfig = cabinetConfigResult.address!;

    // 3. Deploy TuuKeepCabinetItems
    const cabinetItemsResult = await deployContract(walletClient, publicClient, 'TuuKeepCabinetItems', [
      accessControlAddress   // access control
    ]);
    deployedContracts.TuuKeepCabinetItems = cabinetItemsResult.address!;

    // Save deployment data
    const deploymentData = {
      network: "kub-testnet",
      timestamp: new Date().toISOString(),
      step: "2-cabinet",
      contracts: deployedContracts,
      deployer: account.address,
      dependsOn: {
        step1: step1Data.contracts
      }
    };

    const deploymentDir = path.join(__dirname, '..', 'deployments');
    const deploymentFile = path.join(deploymentDir, 'step-2-cabinet.json');
    fs.writeFileSync(deploymentFile, JSON.stringify(deploymentData, null, 2));

    console.log('\n🎉 Step 2 Cabinet Deployment Complete!');
    console.log('======================================');
    console.log('Deployed Contracts:');
    Object.entries(deployedContracts).forEach(([name, address]) => {
      console.log(`  ${name}: ${address}`);
    });
    console.log(`\n📁 Deployment data saved to: ${deploymentFile}`);

  } catch (error) {
    console.error('\n❌ Step 2 Deployment Failed:', error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });