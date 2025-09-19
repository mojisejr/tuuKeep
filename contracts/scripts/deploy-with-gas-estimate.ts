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

async function deployWithProperGasEstimate() {
  console.log('🚀 Deploy with Proper Gas Estimation');
  console.log('====================================');

  // Setup clients
  const privateKey = process.env.KUB_TESTNET_PRIVATE_KEY;
  if (!privateKey) {
    throw new Error('KUB_TESTNET_PRIVATE_KEY not set');
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

  // Try to deploy TuuKeepAccessControl first with gas estimation
  console.log(`\n📦 Deploying TuuKeepAccessControl with proper gas estimation...`);

  try {
    const { abi, bytecode } = await loadContractArtifact('TuuKeepAccessControl');

    // First, estimate gas using eth_estimateGas
    console.log('⛽ Estimating gas...');

    const gasEstimate = await publicClient.estimateGas({
      account,
      data: bytecode as `0x${string}`,
      to: null, // Contract creation
    });

    console.log(`   Gas Estimate: ${gasEstimate.toString()} gas`);
    console.log(`   Gas Estimate: ${(Number(gasEstimate) / 1000000).toFixed(2)}M gas`);

    // Add 20% buffer to gas estimate
    const gasWithBuffer = BigInt(Math.floor(Number(gasEstimate) * 1.2));
    console.log(`   Gas with 20% buffer: ${gasWithBuffer.toString()} gas`);

    // Deploy with estimated gas
    const hash = await walletClient.deployContract({
      abi,
      bytecode: bytecode as `0x${string}`,
      gas: gasWithBuffer,
    });

    console.log(`⏳ Transaction hash: ${hash}`);

    // Wait for receipt
    const receipt = await publicClient.waitForTransactionReceipt({ hash });

    console.log(`✅ Status: ${receipt.status === 'success' ? 'SUCCESS' : 'FAILED'}`);
    console.log(`⛽ Gas Used: ${receipt.gasUsed.toString()}`);
    console.log(`📦 Block Number: ${receipt.blockNumber.toString()}`);

    if (receipt.contractAddress) {
      console.log(`📍 Contract Address: ${receipt.contractAddress}`);

      // Verify contract code exists
      const code = await publicClient.getCode({
        address: receipt.contractAddress
      });

      if (code && code !== '0x') {
        console.log(`✅ Contract Code: EXISTS (${code.length} chars)`);
        console.log(`🎉 DEPLOYMENT SUCCESSFUL!`);
      } else {
        console.log(`❌ Contract Code: DOES NOT EXIST`);
      }
    }

  } catch (error) {
    console.log(`❌ Deployment failed: ${error}`);
  }
}

deployWithProperGasEstimate()
  .then(() => {
    console.log('\n🚀 Deployment attempt complete');
  })
  .catch((error) => {
    console.error('Error:', error);
  });