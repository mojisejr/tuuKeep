import { createWalletClient, http, parseEther, publicActions } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { config } from 'dotenv';

// Load environment variables
config();

async function testKubTestnet() {
  try {
    console.log('🔗 Testing KUB Testnet connection...');

    // Create the KUB Testnet chain configuration
    const kubTestnet = {
      id: 25925,
      name: 'KUB Testnet',
      network: 'kub-testnet',
      nativeCurrency: { name: 'tKUB', symbol: 'tKUB', decimals: 18 },
      rpcUrls: {
        default: { http: [process.env.KUB_TESTNET_RPC_URL || 'https://rpc-testnet.bitkubchain.io'] },
        public: { http: [process.env.KUB_TESTNET_RPC_URL || 'https://rpc-testnet.bitkubchain.io'] },
      },
      blockExplorers: {
        default: { name: 'KubScan Testnet', url: 'https://testnet.kubscan.com' },
      },
      testnet: true,
    };

    // Create account from private key
    const privateKey = process.env.KUB_TESTNET_PRIVATE_KEY;
    if (!privateKey || privateKey === 'your_kub_testnet_private_key_here') {
      throw new Error('KUB_TESTNET_PRIVATE_KEY not set properly');
    }

    const formattedPrivateKey = privateKey.startsWith('0x') ? privateKey : `0x${privateKey}`;
    const account = privateKeyToAccount(formattedPrivateKey as `0x${string}`);

    // Create wallet client with public actions
    const client = createWalletClient({
      account,
      chain: kubTestnet,
      transport: http(process.env.KUB_TESTNET_RPC_URL),
    }).extend(publicActions);

    // Get current block number
    const blockNumber = await client.getBlockNumber();
    console.log('✅ Current block number:', blockNumber);

    // Get account balance
    const balance = await client.getBalance({ address: account.address });
    console.log('✅ Account address:', account.address);
    console.log('✅ Account balance:', parseFloat((Number(balance) / 1e18).toFixed(6)), 'tKUB');

    // Test if we have enough balance for deployment (need at least 0.1 tKUB)
    const minBalance = parseEther('0.1');
    if (balance >= minBalance) {
      console.log('✅ Sufficient balance for contract deployment');
    } else {
      console.log('⚠️ Low balance - may need more tKUB for deployment');
    }

    return true;
  } catch (error) {
    console.error('❌ Connection failed:', error);
    return false;
  }
}

testKubTestnet().then((success) => {
  if (success) {
    console.log('🎉 KUB Testnet environment ready!');
    process.exit(0);
  } else {
    console.log('💥 KUB Testnet environment needs setup');
    process.exit(1);
  }
});