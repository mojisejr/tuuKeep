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

async function deployContract(
  walletClient: any,
  publicClient: any,
  contractName: string,
  constructorArgs: any[] = []
) {
  console.log(`\n📦 Deploying ${contractName}...`);

  try {
    const { abi, bytecode } = await loadContractArtifact(contractName);

    console.log('   ⛽ Estimating gas...');
    const gasEstimate = await publicClient.estimateGas({
      account: walletClient.account,
      data: bytecode as `0x${string}`,
      to: null,
    });

    const gasWithBuffer = BigInt(Math.floor(Number(gasEstimate) * 1.2));
    console.log(`   Gas Estimate: ${gasEstimate.toString()} gas (${(Number(gasEstimate) / 1000000).toFixed(2)}M)`);
    console.log(`   Gas with Buffer: ${gasWithBuffer.toString()} gas`);

    const hash = await walletClient.deployContract({
      abi,
      bytecode: bytecode as `0x${string}`,
      args: constructorArgs,
      gas: gasWithBuffer,
    });

    console.log(`   ⏳ Transaction hash: ${hash}`);

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
  console.log('🚀 Final Foundation Contracts Deployment');
  console.log('=======================================');
  console.log('Using London EVM target for KUB testnet compatibility\n');

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

  const deployedContracts: { [key: string]: string } = {};
  const deploymentResults: any[] = [];
  const contractsDir = path.dirname(__dirname);

  // Step 1: Deploy TuuKeepAccessControl (no constructor args)
  const accessControlResult = await deployContract(
    walletClient,
    publicClient,
    'TuuKeepAccessControl'
  );
  deploymentResults.push({ name: 'TuuKeepAccessControl', ...accessControlResult });

  let canProceed = accessControlResult.success;

  if (accessControlResult.success) {
    deployedContracts.TuuKeepAccessControl = accessControlResult.address!;

    // Step 2: Deploy Randomness (admin address)
    const randomnessResult = await deployContract(
      walletClient,
      publicClient,
      'Randomness',
      [account.address]
    );
    deploymentResults.push({ name: 'Randomness', ...randomnessResult });

    if (randomnessResult.success) {
      deployedContracts.Randomness = randomnessResult.address!;
    }

    // Wait a moment for access control to be fully confirmed
    console.log('\n⏳ Waiting 10 seconds for AccessControl to be fully confirmed...');
    await new Promise(resolve => setTimeout(resolve, 10000));

    // Step 3: Deploy TuuCoinBase with access control reference
    // This one might fail due to validation, but let's try
    const tuuCoinBaseResult = await deployContract(
      walletClient,
      publicClient,
      'TuuCoinBase',
      [accessControlResult.address, account.address]
    );
    deploymentResults.push({ name: 'TuuCoinBase', ...tuuCoinBaseResult });

    if (tuuCoinBaseResult.success) {
      deployedContracts.TuuCoinBase = tuuCoinBaseResult.address!;
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
      console.log(`   Explorer: https://testnet.kubscan.com/address/${result.address}`);
    } else {
      console.log(`❌ ${result.name}: FAILED - ${result.error}`);
    }
    console.log('');
  }

  // Save deployment data
  if (Object.keys(deployedContracts).length > 0) {
    const deploymentData = {
      network: "kub-testnet",
      timestamp: new Date().toISOString(),
      step: "foundation-final",
      contracts: deployedContracts,
      deployer: account.address,
      evmVersion: "london",
      success: deploymentResults.filter(r => r.success).length,
      total: deploymentResults.length,
      note: "Deployed with London EVM target for KUB testnet compatibility"
    };

    const deploymentDir = path.join(contractsDir, 'deployments');
    if (!fs.existsSync(deploymentDir)) {
      fs.mkdirSync(deploymentDir, { recursive: true });
    }

    const deploymentFile = path.join(deploymentDir, 'foundation-final.json');
    fs.writeFileSync(deploymentFile, JSON.stringify(deploymentData, null, 2));
    console.log(`📁 Deployment data saved to: ${deploymentFile}`);
  }

  const successCount = deploymentResults.filter(r => r.success).length;
  console.log(`\n🎯 Final Result: ${successCount}/${deploymentResults.length} contracts deployed successfully`);

  if (successCount > 0) {
    console.log('\n✅ Foundation deployment phase completed!');
    console.log('Next steps: Deploy remaining contracts (Steps 2-4)');
  } else {
    console.log('\n❌ Foundation deployment failed');
    console.log('Review errors above and retry');
  }
}

main()
  .then(() => {
    console.log('\n🚀 Foundation deployment complete');
  })
  .catch((error) => {
    console.error('Error:', error);
  });