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
  console.log('🪙 Simple Token Deployment Test');
  console.log('===============================');

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

  // Load SimpleToken artifact
  const artifactPath = path.join(path.dirname(__dirname), 'artifacts', 'contracts', 'SimpleToken.sol', 'SimpleToken.json');
  const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf-8'));

  console.log('📦 Deploying SimpleToken...');

  try {
    const hash = await walletClient.deployContract({
      abi: artifact.abi,
      bytecode: artifact.bytecode as `0x${string}`,
      args: [account.address], // admin address
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

      // Test token functions
      if (code && code !== '0x') {
        console.log('\n🔧 Testing token functions...');

        // Read name
        const name = await publicClient.readContract({
          address: receipt.contractAddress,
          abi: artifact.abi,
          functionName: 'name',
        });
        console.log(`   Name: ${name}`);

        // Read symbol
        const symbol = await publicClient.readContract({
          address: receipt.contractAddress,
          abi: artifact.abi,
          functionName: 'symbol',
        });
        console.log(`   Symbol: ${symbol}`);

        // Read total supply
        const totalSupply = await publicClient.readContract({
          address: receipt.contractAddress,
          abi: artifact.abi,
          functionName: 'totalSupply',
        });
        console.log(`   Total Supply: ${totalSupply.toString()}`);

        // Read admin
        const admin = await publicClient.readContract({
          address: receipt.contractAddress,
          abi: artifact.abi,
          functionName: 'admin',
        });
        console.log(`   Admin: ${admin}`);

        console.log('\n✅ SimpleToken deployment and testing successful!');
        console.log('This confirms KUB testnet can deploy ERC20 tokens.');
      }
    }

  } catch (error) {
    console.log(`❌ Deployment failed: ${error}`);
  }
}

main()
  .then(() => {
    console.log('\n🪙 Simple token deployment complete');
  })
  .catch((error) => {
    console.error('Error:', error);
  });