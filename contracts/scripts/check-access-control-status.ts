import { createPublicClient, http } from 'viem';
import { config } from 'dotenv';

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
  console.log('🔍 Checking Access Control Contract Status');
  console.log('==========================================');

  const publicClient = createPublicClient({
    chain: kubTestnet,
    transport: http(),
  });

  const addresses = [
    "0xb6144a66b1553b8028e60e2ccfff6bfff74b270e", // From deployment status
    "0x4d7665326027fc2f3fd65883e281f8c9cdfaaf1d", // From deploy-single-test.ts
  ];

  for (const address of addresses) {
    console.log(`\n📍 Checking address: ${address}`);

    try {
      // Check if address has code
      const code = await publicClient.getCode({ address: address as `0x${string}` });
      console.log(`   Code exists: ${code && code !== '0x' ? 'YES' : 'NO'}`);
      if (code && code !== '0x') {
        console.log(`   Code length: ${code.length} chars`);
      }

      // Get balance
      const balance = await publicClient.getBalance({ address: address as `0x${string}` });
      console.log(`   Balance: ${balance.toString()} wei`);

      // Check transaction count
      const txCount = await publicClient.getTransactionCount({ address: address as `0x${string}` });
      console.log(`   Transaction count: ${txCount}`);

      // Explorer link
      console.log(`   🔗 Explorer: https://testnet.kubscan.com/address/${address}`);

    } catch (error) {
      console.log(`   ❌ Error checking address: ${error}`);
    }
  }

  // Also check current deployer
  const deployerAddress = "0x4C06524B1bd7AA002747252257bBE0C472735A6D";
  console.log(`\n📍 Checking deployer: ${deployerAddress}`);

  try {
    const balance = await publicClient.getBalance({ address: deployerAddress as `0x${string}` });
    console.log(`   Balance: ${balance.toString()} wei`);

    const txCount = await publicClient.getTransactionCount({ address: deployerAddress as `0x${string}` });
    console.log(`   Transaction count: ${txCount}`);
  } catch (error) {
    console.log(`   ❌ Error checking deployer: ${error}`);
  }
}

main()
  .then(() => {
    console.log('\n🔍 Contract status check complete');
  })
  .catch((error) => {
    console.error('Error:', error);
  });