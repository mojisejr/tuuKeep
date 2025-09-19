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

async function main() {
  console.log('🧪 Test Contract Deployment');
  console.log('===========================');

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
  console.log(`Balance: ${formatEther(await publicClient.getBalance({ address: account.address }))} KUB\n`);

  // Load TestContract artifact
  const artifactPath = path.join(path.dirname(__dirname), 'artifacts', 'contracts', 'TestContract.sol', 'TestContract.json');
  const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf-8'));

  console.log('📦 Deploying TestContract...');

  try {
    const hash = await walletClient.deployContract({
      abi: artifact.abi,
      bytecode: artifact.bytecode as `0x${string}`,
      args: ["KUB Testnet Test"],
    });

    console.log(`⏳ Transaction hash: ${hash}`);

    const receipt = await publicClient.waitForTransactionReceipt({ hash });

    console.log(`✅ Status: ${receipt.status === 'success' ? 'SUCCESS' : 'FAILED'}`);
    console.log(`⛽ Gas Used: ${receipt.gasUsed.toString()}`);
    console.log(`📍 Contract Address: ${receipt.contractAddress}`);

    if (receipt.contractAddress) {
      const code = await publicClient.getCode({ address: receipt.contractAddress });
      console.log(`✅ Contract Code: ${code && code !== '0x' ? 'EXISTS' : 'MISSING'}`);
      console.log(`🔗 Explorer: https://testnet.kubscan.com/address/${receipt.contractAddress}`);

      // Test contract interaction
      if (code && code !== '0x') {
        console.log('\n🔧 Testing contract interaction...');

        // Read name
        const nameResult = await publicClient.readContract({
          address: receipt.contractAddress,
          abi: artifact.abi,
          functionName: 'getName',
        });
        console.log(`   Name: ${nameResult}`);

        // Read owner
        const ownerResult = await publicClient.readContract({
          address: receipt.contractAddress,
          abi: artifact.abi,
          functionName: 'getOwner',
        });
        console.log(`   Owner: ${ownerResult}`);

        // Test write operation
        const writeHash = await walletClient.writeContract({
          address: receipt.contractAddress,
          abi: artifact.abi,
          functionName: 'setValue',
          args: [123],
        });
        console.log(`   Write Transaction: ${writeHash}`);

        const writeReceipt = await publicClient.waitForTransactionReceipt({ hash: writeHash });
        console.log(`   Write Status: ${writeReceipt.status === 'success' ? 'SUCCESS' : 'FAILED'}`);
      }
    }

  } catch (error) {
    console.log(`❌ Deployment failed: ${error}`);
  }
}

main()
  .then(() => {
    console.log('\n🧪 Test contract deployment complete');
  })
  .catch((error) => {
    console.error('Error:', error);
  });