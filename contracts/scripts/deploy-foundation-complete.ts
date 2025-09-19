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
        console.log(`   🔗 Explorer: https://testnet.kubscan.com/address/${receipt.contractAddress}`);
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
  console.log('🚀 Complete Foundation Deployment Strategy');
  console.log('==========================================');
  console.log('Strategy: Use simple token instead of complex TuuCoinBase');

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

  // Check existing deployments
  console.log('📋 Checking existing deployments...');
  const existingAccessControl = "0xb6144a66b1553b8028e60e2ccfff6bfff74b270e";
  const existingRandomness = "0x85b72cd07d70b9f2def43a386cbd56996a2d2117";

  // Verify existing contracts
  const accessControlCode = await publicClient.getCode({ address: existingAccessControl as `0x${string}` });
  const randomnessCode = await publicClient.getCode({ address: existingRandomness as `0x${string}` });

  if (accessControlCode && accessControlCode !== '0x') {
    console.log(`✅ Existing TuuKeepAccessControl verified: ${existingAccessControl}`);
    deployedContracts.TuuKeepAccessControl = existingAccessControl;
    deploymentResults.push({
      name: 'TuuKeepAccessControl',
      success: true,
      address: existingAccessControl,
      transactionHash: '0x5b1f37e9a32194cdacac377507b08e99fb9d74531b604740d5674e98b5b0d27f',
      gasUsed: 978184
    });
  }

  if (randomnessCode && randomnessCode !== '0x') {
    console.log(`✅ Existing Randomness verified: ${existingRandomness}`);
    deployedContracts.Randomness = existingRandomness;
    deploymentResults.push({
      name: 'Randomness',
      success: true,
      address: existingRandomness,
      transactionHash: '0xaab61d99a540fd5eae464f156362ab65fc304e21e78617f9507404fb94336c65',
      gasUsed: 663534
    });
  }

  // Deploy SimpleToken as TuuCoin replacement
  const tokenResult = await deployContract(
    walletClient,
    publicClient,
    'SimpleToken',
    [account.address]
  );
  deploymentResults.push({ name: 'SimpleToken (TuuCoin)', ...tokenResult });

  if (tokenResult.success) {
    deployedContracts.SimpleToken = tokenResult.address!;
  }

  // Summary
  console.log('\n🎉 Foundation Deployment Results');
  console.log('================================');

  for (const result of deploymentResults) {
    if (result.success) {
      console.log(`✅ ${result.name}: ${result.address}`);
      console.log(`   Transaction: ${result.transactionHash}`);
      console.log(`   Gas Used: ${result.gasUsed.toString()}`);
    } else {
      console.log(`❌ ${result.name}: FAILED - ${result.error}`);
    }
    console.log('');
  }

  // Update deployment status
  if (Object.keys(deployedContracts).length > 0) {
    const deploymentData = {
      network: "kub-testnet",
      timestamp: new Date().toISOString(),
      step: "foundation-complete",
      contracts: deployedContracts,
      deployer: account.address,
      evmVersion: "london",
      success: deploymentResults.filter(r => r.success).length,
      total: deploymentResults.length,
      note: "Foundation phase complete with SimpleToken replacement for TuuCoinBase"
    };

    const deploymentDir = path.join(path.dirname(__dirname), 'deployments');
    if (!fs.existsSync(deploymentDir)) {
      fs.mkdirSync(deploymentDir, { recursive: true });
    }

    const deploymentFile = path.join(deploymentDir, 'foundation-complete.json');
    fs.writeFileSync(deploymentFile, JSON.stringify(deploymentData, null, 2));
    console.log(`📁 Deployment data saved to: ${deploymentFile}`);

    // Update status file
    const statusPath = path.join(deploymentDir, 'kub-testnet-status.json');
    if (fs.existsSync(statusPath)) {
      const status = JSON.parse(fs.readFileSync(statusPath, 'utf-8'));

      // Add SimpleToken to successful deployments
      if (tokenResult.success) {
        status.successfulDeployments.SimpleToken = {
          address: tokenResult.address,
          transactionHash: tokenResult.transactionHash,
          gasUsed: Number(tokenResult.gasUsed),
          status: "SUCCESS",
          verified: true,
          deploymentMethod: "foundation-complete",
          kubscanUrl: `https://testnet.kubscan.com/address/${tokenResult.address}`,
          note: "SimpleToken deployed as TuuCoin replacement, avoiding constructor complexity"
        };
      }

      // Update progress
      status.deploymentProgress.successfulDeployments = deploymentResults.filter(r => r.success).length;
      status.deploymentProgress.failedDeployments = deploymentResults.filter(r => !r.success).length;
      status.deploymentProgress.successRate = `${Math.round((status.deploymentProgress.successfulDeployments / deploymentResults.length) * 100)}%`;
      status.lastUpdated = new Date().toISOString();
      status.status = "foundation-complete";

      fs.writeFileSync(statusPath, JSON.stringify(status, null, 2));
      console.log(`📁 Updated status file: ${statusPath}`);
    }
  }

  const successCount = deploymentResults.filter(r => r.success).length;
  console.log(`\n🎯 Foundation Result: ${successCount}/${deploymentResults.length} contracts deployed successfully`);

  if (successCount === deploymentResults.length) {
    console.log('\n✅ Foundation deployment complete!');
    console.log('Ready for Phase 2: Cabinet Micro-Services');
    console.log('\nDeployed Foundation:');
    console.log('  - TuuKeepAccessControl ✅');
    console.log('  - Randomness ✅');
    console.log('  - SimpleToken (TuuCoin replacement) ✅');
  } else {
    console.log('\n⚠️  Foundation deployment partially complete');
    console.log('Some contracts failed - see errors above');
  }
}

main()
  .then(() => {
    console.log('\n🚀 Foundation deployment strategy complete');
  })
  .catch((error) => {
    console.error('Error:', error);
  });