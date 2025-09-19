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

async function checkTransactionStatus() {
  const publicClient = createPublicClient({
    chain: kubTestnet,
    transport: http(),
  });

  // Transaction hashes from recent deployment
  const txHashes = [
    '0x541db9b29d9a2aa0456bac43e89c044b5ed0eb4135ea5f15b6a9029f9acbf546', // TuuKeepAccessControl
    '0x89f81fd03db462db615595dbcb13ae4590f49e5796dca2a0d124d87557fe6eb7', // TuuCoinBase
    '0x87cfb9b4b3edd237ef72b6ef87b5fedda094a13bd575018146d1249c689f2c0d', // Randomness
  ];

  const contracts = ['TuuKeepAccessControl', 'TuuCoinBase', 'Randomness'];

  console.log('🔍 Checking Transaction Status on KUB Testnet');
  console.log('===============================================');

  for (let i = 0; i < txHashes.length; i++) {
    const txHash = txHashes[i];
    const contractName = contracts[i];

    console.log(`\n📋 ${contractName}`);
    console.log(`Transaction Hash: ${txHash}`);

    try {
      // Get transaction receipt
      const receipt = await publicClient.getTransactionReceipt({
        hash: txHash as `0x${string}`
      });

      console.log(`✅ Status: ${receipt.status === 'success' ? 'SUCCESS' : 'FAILED'}`);
      console.log(`⛽ Gas Used: ${receipt.gasUsed.toString()}`);
      console.log(`📦 Block Number: ${receipt.blockNumber.toString()}`);

      if (receipt.contractAddress) {
        console.log(`📍 Contract Address: ${receipt.contractAddress}`);

        // Check if contract code exists
        const code = await publicClient.getCode({
          address: receipt.contractAddress
        });

        if (code && code !== '0x') {
          console.log(`✅ Contract Code: EXISTS (${code.length} chars)`);
        } else {
          console.log(`❌ Contract Code: DOES NOT EXIST`);
        }
      } else {
        console.log(`❌ No Contract Address - Deployment Failed`);
      }

      // Check for any logs/events
      if (receipt.logs && receipt.logs.length > 0) {
        console.log(`📋 Events: ${receipt.logs.length} log entries`);
      } else {
        console.log(`⚠️  No Events Emitted`);
      }

    } catch (error) {
      console.log(`❌ Error checking transaction: ${error}`);
    }
  }
}

checkTransactionStatus()
  .then(() => {
    console.log('\n🔍 Transaction status check complete');
  })
  .catch((error) => {
    console.error('Error:', error);
  });