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

async function checkGasRequirements() {
  console.log('⛽ Checking Gas Requirements for KUB Testnet');
  console.log('============================================');

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

  const contracts = ['TuuKeepAccessControl', 'TuuCoinBase', 'Randomness'];

  for (const contractName of contracts) {
    console.log(`\n📦 ${contractName}`);

    try {
      const { abi, bytecode } = await loadContractArtifact(contractName);

      // Check bytecode size
      const bytecodeSize = (bytecode.length - 2) / 2; // Remove 0x and convert hex to bytes
      const sizeInKB = (bytecodeSize / 1024).toFixed(2);
      console.log(`   Bytecode Size: ${bytecodeSize} bytes (${sizeInKB} KB)`);

      if (bytecodeSize > 24576) { // 24KB EIP-170 limit
        console.log(`   ⚠️  Warning: Exceeds EIP-170 limit (24KB)`);
      }

      // Estimate gas for deployment
      try {
        let gasEstimate;

        if (contractName === 'TuuCoinBase') {
          // TuuCoinBase needs constructor args
          gasEstimate = await publicClient.estimateContractDeploymentGas({
            abi,
            bytecode: bytecode as `0x${string}`,
            args: [
              '0x440d8d9ee028342943b976b6a3325220f05f4e26', // dummy access control address
              account.address // admin
            ],
            account,
          });
        } else {
          // Other contracts have no constructor args
          gasEstimate = await publicClient.estimateContractDeploymentGas({
            abi,
            bytecode: bytecode as `0x${string}`,
            account,
          });
        }

        console.log(`   Gas Estimate: ${gasEstimate.toString()} gas`);
        console.log(`   Gas Estimate: ${(Number(gasEstimate) / 1000000).toFixed(2)}M gas`);

        // Check if our 6M limit is reasonable
        if (gasEstimate > 5000000n) {
          console.log(`   ⚠️  Warning: Requires > 5M gas`);
        }

      } catch (gasError) {
        console.log(`   ❌ Gas estimation failed: ${gasError}`);
      }

    } catch (error) {
      console.log(`   ❌ Error: ${error}`);
    }
  }

  // Check network gas limit
  try {
    const latestBlock = await publicClient.getBlock({ blockTag: 'latest' });
    console.log(`\n🔗 Network Info:`);
    console.log(`   Latest Block: ${latestBlock.number.toString()}`);
    console.log(`   Block Gas Limit: ${latestBlock.gasLimit.toString()}`);
    console.log(`   Block Gas Limit: ${(Number(latestBlock.gasLimit) / 1000000).toFixed(2)}M gas`);
  } catch (error) {
    console.log(`\n❌ Could not get network info: ${error}`);
  }
}

checkGasRequirements()
  .then(() => {
    console.log('\n⛽ Gas requirements check complete');
  })
  .catch((error) => {
    console.error('Error:', error);
  });