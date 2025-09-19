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
  const contractsDir = path.dirname(__dirname);
  const possiblePaths = [
    path.join(contractsDir, `artifacts/contracts/${contractName}.sol/${contractName}.json`),
    path.join(contractsDir, `artifacts/contracts/Utils/Security/${contractName}.sol/${contractName}.json`),
    path.join(contractsDir, `artifacts/contracts/Utils/${contractName}.sol/${contractName}.json`),
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

async function main() {
  console.log('🧪 Single Contract Deployment Test');
  console.log('===================================');

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

  // Test TuuCoinBase with hardcoded access control address
  const existingAccessControl = "0x4d7665326027fc2f3fd65883e281f8c9cdfaaf1d"; // From previous successful deployment

  console.log(`\n📦 Testing TuuCoinBase with existing AccessControl: ${existingAccessControl}`);

  try {
    const { abi, bytecode } = await loadContractArtifact('TuuCoinBase');

    console.log('⛽ Estimating gas...');
    const gasEstimate = await publicClient.estimateGas({
      account: walletClient.account,
      data: bytecode as `0x${string}`,
      to: null,
    });

    console.log(`Gas estimation failed, trying deployment...`);

    // Deploy with constructor args
    const hash = await walletClient.deployContract({
      abi,
      bytecode: bytecode as `0x${string}`,
      args: [existingAccessControl, account.address],
      gas: BigInt(6000000), // Large gas limit
    });

    console.log(`⏳ Transaction hash: ${hash}`);

    const receipt = await publicClient.waitForTransactionReceipt({ hash });

    console.log(`Status: ${receipt.status === 'success' ? 'SUCCESS' : 'FAILED'}`);
    console.log(`Gas Used: ${receipt.gasUsed.toString()}`);
    console.log(`Contract Address: ${receipt.contractAddress}`);

    if (receipt.contractAddress) {
      const code = await publicClient.getCode({ address: receipt.contractAddress });
      console.log(`Contract Code: ${code && code !== '0x' ? 'EXISTS' : 'MISSING'}`);
    }

  } catch (error) {
    console.log(`❌ Deployment failed: ${error}`);

    // Let's try to get more detailed error information
    if (error.toString().includes('execution reverted')) {
      console.log('Checking access control contract exists...');

      try {
        const code = await publicClient.getCode({ address: existingAccessControl as `0x${string}` });
        console.log(`AccessControl contract code exists: ${code && code !== '0x' ? 'YES' : 'NO'}`);
        console.log(`Code length: ${code ? code.length : 'N/A'}`);
      } catch (codeCheckError) {
        console.log(`Error checking access control code: ${codeCheckError}`);
      }
    }
  }
}

main()
  .then(() => {
    console.log('\n🧪 Single contract test complete');
  })
  .catch((error) => {
    console.error('Error:', error);
  });