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

async function deployContractWithEstimate(
  walletClient: any,
  publicClient: any,
  contractName: string,
  constructorArgs: any[] = []
) {
  console.log(`\n📦 Deploying ${contractName}...`);

  try {
    const { abi, bytecode } = await loadContractArtifact(contractName);

    // Estimate gas
    console.log('   ⛽ Estimating gas...');
    const gasEstimate = await publicClient.estimateGas({
      account: walletClient.account,
      data: bytecode as `0x${string}`,
      to: null,
    });

    const gasWithBuffer = BigInt(Math.floor(Number(gasEstimate) * 1.2));
    console.log(`   Gas Estimate: ${gasEstimate.toString()} gas (${(Number(gasEstimate) / 1000000).toFixed(2)}M)`);
    console.log(`   Gas with Buffer: ${gasWithBuffer.toString()} gas`);

    // Deploy
    const hash = await walletClient.deployContract({
      abi,
      bytecode: bytecode as `0x${string}`,
      args: constructorArgs,
      gas: gasWithBuffer,
    });

    console.log(`   ⏳ Transaction hash: ${hash}`);

    // Wait for receipt
    const receipt = await publicClient.waitForTransactionReceipt({ hash });

    console.log(`   ✅ Status: ${receipt.status === 'success' ? 'SUCCESS' : 'FAILED'}`);
    console.log(`   ⛽ Gas Used: ${receipt.gasUsed.toString()}`);
    console.log(`   📦 Block Number: ${receipt.blockNumber.toString()}`);

    if (receipt.contractAddress) {
      console.log(`   📍 Contract Address: ${receipt.contractAddress}`);

      // Verify contract code exists
      const code = await publicClient.getCode({
        address: receipt.contractAddress
      });

      if (code && code !== '0x') {
        console.log(`   ✅ Contract Code: EXISTS (${code.length} chars)`);
        return {
          success: true,
          address: receipt.contractAddress,
          transactionHash: hash,
          gasUsed: receipt.gasUsed,
        };
      } else {
        console.log(`   ❌ Contract Code: DOES NOT EXIST`);
        return { success: false, error: 'No contract code at address' };
      }
    } else {
      console.log(`   ❌ No Contract Address Generated`);
      return { success: false, error: 'No contract address' };
    }

  } catch (error) {
    console.log(`   ❌ Deployment failed: ${error}`);
    return { success: false, error: error.toString() };
  }
}

async function main() {
  console.log('🚀 Fixed Foundation Contracts Deployment');
  console.log('========================================');

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

  const deployedContracts: { [key: string]: string } = {};
  const deploymentResults: any[] = [];
  const contractsDir = path.dirname(__dirname);

  // 1. Deploy TuuKeepAccessControl
  const accessControlResult = await deployContractWithEstimate(
    walletClient,
    publicClient,
    'TuuKeepAccessControl'
  );
  deploymentResults.push({ name: 'TuuKeepAccessControl', ...accessControlResult });

  if (accessControlResult.success) {
    deployedContracts.TuuKeepAccessControl = accessControlResult.address!;

    // 2. Deploy TuuCoinBase
    const tuuCoinBaseResult = await deployContractWithEstimate(
      walletClient,
      publicClient,
      'TuuCoinBase',
      [accessControlResult.address, account.address]
    );
    deploymentResults.push({ name: 'TuuCoinBase', ...tuuCoinBaseResult });

    if (tuuCoinBaseResult.success) {
      deployedContracts.TuuCoinBase = tuuCoinBaseResult.address!;
    }

    // 3. Deploy Randomness
    const randomnessResult = await deployContractWithEstimate(
      walletClient,
      publicClient,
      'Randomness',
      [account.address]  // Admin address for Randomness contract
    );
    deploymentResults.push({ name: 'Randomness', ...randomnessResult });

    if (randomnessResult.success) {
      deployedContracts.Randomness = randomnessResult.address!;
    }
  }

  // Summary
  console.log('\n🎉 Deployment Results');
  console.log('=====================');

  for (const result of deploymentResults) {
    if (result.success) {
      console.log(`✅ ${result.name}: ${result.address}`);
      console.log(`   Transaction: ${result.transactionHash}`);
      console.log(`   Gas Used: ${result.gasUsed.toString()}`);
    } else {
      console.log(`❌ ${result.name}: FAILED - ${result.error}`);
    }
  }

  // Save deployment data
  if (Object.keys(deployedContracts).length > 0) {
    const deploymentData = {
      network: "kub-testnet",
      timestamp: new Date().toISOString(),
      step: "foundation-fixed",
      contracts: deployedContracts,
      deployer: account.address,
      evmVersion: "london",
      success: deploymentResults.filter(r => r.success).length,
      total: deploymentResults.length,
    };

    const deploymentDir = path.join(contractsDir, 'deployments');
    if (!fs.existsSync(deploymentDir)) {
      fs.mkdirSync(deploymentDir, { recursive: true });
    }

    const deploymentFile = path.join(deploymentDir, 'foundation-fixed.json');
    fs.writeFileSync(deploymentFile, JSON.stringify(deploymentData, null, 2));
    console.log(`\n📁 Deployment data saved to: ${deploymentFile}`);
  }

  console.log(`\n🎯 Success Rate: ${deploymentResults.filter(r => r.success).length}/${deploymentResults.length} contracts deployed`);
}

main()
  .then(() => {
    console.log('\n🚀 Fixed deployment complete');
  })
  .catch((error) => {
    console.error('Error:', error);
  });