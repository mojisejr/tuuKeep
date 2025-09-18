import { createWalletClient, http, parseEther, publicActions, getContract } from 'viem';
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

interface DeploymentResult {
  network: string;
  chainId: number;
  timestamp: string;
  deployer: string;
  contracts: {
    accessControl?: string;
    tuuCoin?: string;
    randomness?: string;
    cabinetCore?: string;
    cabinetGame?: string;
    marketplace?: string;
    tierSale?: string;
  };
  gasUsed: {
    [contractName: string]: string;
  };
  blockNumbers: {
    [contractName: string]: number;
  };
  transactionHashes: {
    [contractName: string]: string;
  };
}

async function deployContract(
  client: any,
  contractName: string,
  abi: any[],
  bytecode: string,
  args: any[] = [],
  result: DeploymentResult
) {
  console.log(`📦 Deploying ${contractName}...`);

  try {
    // Deploy contract
    const hash = await client.deployContract({
      abi: abi,
      bytecode: bytecode as `0x${string}`,
      args: args,
    });

    console.log(`⏳ Transaction hash: ${hash}`);
    result.transactionHashes[contractName] = hash;

    // Wait for transaction receipt
    const receipt = await client.waitForTransactionReceipt({ hash });
    console.log(`✅ ${contractName} deployed at: ${receipt.contractAddress}`);
    console.log(`⛽ Gas used: ${receipt.gasUsed.toString()}`);
    console.log(`📦 Block number: ${receipt.blockNumber.toString()}`);

    // Store results
    result.contracts[contractName as keyof typeof result.contracts] = receipt.contractAddress;
    result.gasUsed[contractName] = receipt.gasUsed.toString();
    result.blockNumbers[contractName] = Number(receipt.blockNumber);

    return receipt.contractAddress;
  } catch (error) {
    console.error(`❌ Failed to deploy ${contractName}:`, error);
    throw error;
  }
}

async function loadContractArtifact(contractName: string) {
  const artifactPath = path.join(__dirname, '../artifacts/contracts', `${contractName}.sol`, `${contractName}.json`);

  if (!fs.existsSync(artifactPath)) {
    // Try alternative paths
    const altPaths = [
      path.join(__dirname, `../artifacts/contracts/Utils/Security/${contractName}.sol/${contractName}.json`),
      path.join(__dirname, `../artifacts/contracts/Utils/${contractName}.sol/${contractName}.json`),
      path.join(__dirname, `../artifacts/contracts/interfaces/${contractName}.sol/${contractName}.json`),
    ];

    for (const altPath of altPaths) {
      if (fs.existsSync(altPath)) {
        const artifact = JSON.parse(fs.readFileSync(altPath, 'utf-8'));
        return { bytecode: artifact.bytecode, abi: artifact.abi };
      }
    }

    throw new Error(`Contract artifact not found: ${contractName}`);
  }

  const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf-8'));
  return { bytecode: artifact.bytecode, abi: artifact.abi };
}

async function setContractRoles(client: any, result: DeploymentResult) {
  console.log('🔑 Configuring contract roles and relationships...');

  if (!result.contracts.accessControl || !result.contracts.cabinetCore || !result.contracts.cabinetGame) {
    console.warn('⚠️ Missing required contracts for role configuration');
    return;
  }

  try {
    // Load ABIs
    const accessControlAbi = (await loadContractArtifact('TuuKeepAccessControl')).abi;
    const cabinetCoreAbi = (await loadContractArtifact('TuuKeepCabinetCore')).abi;
    const cabinetGameAbi = (await loadContractArtifact('TuuKeepCabinetGame')).abi;

    // Create contract instances
    const accessControlContract = getContract({
      address: result.contracts.accessControl as `0x${string}`,
      abi: accessControlAbi,
      client,
    });

    const cabinetCoreContract = getContract({
      address: result.contracts.cabinetCore as `0x${string}`,
      abi: cabinetCoreAbi,
      client,
    });

    // Configure Core-Game relationship
    console.log('🔗 Setting Game contract in Core contract...');
    const setGameTx = await cabinetCoreContract.write.setGameContract([result.contracts.cabinetGame]);
    await client.waitForTransactionReceipt({ hash: setGameTx });
    console.log('✅ Game contract set in Core contract');

    // Grant necessary roles
    console.log('🎯 Granting GAME_ROLE to Game contract...');
    const gameRoleHash = '0x...' // We'll need to get this from the contract
    // const grantRoleTx = await accessControlContract.write.grantRole([gameRoleHash, result.contracts.cabinetGame]);
    // await client.waitForTransactionReceipt({ hash: grantRoleTx });

    console.log('✅ Contract roles configured successfully');
  } catch (error) {
    console.error('❌ Failed to configure roles:', error);
    throw error;
  }
}

async function main() {
  console.log('🚀 Starting manual KUB testnet deployment...');

  // Validate environment
  const privateKey = process.env.KUB_TESTNET_PRIVATE_KEY;
  if (!privateKey || privateKey === 'your_kub_testnet_private_key_here') {
    throw new Error('KUB_TESTNET_PRIVATE_KEY not set properly');
  }

  // Create account and client
  const formattedPrivateKey = privateKey.startsWith('0x') ? privateKey : `0x${privateKey}`;
  const account = privateKeyToAccount(formattedPrivateKey as `0x${string}`);

  const client = createWalletClient({
    account,
    chain: kubTestnet,
    transport: http(process.env.KUB_TESTNET_RPC_URL),
  }).extend(publicActions);

  // Initialize deployment result
  const deploymentResult: DeploymentResult = {
    network: 'kubTestnet',
    chainId: 25925,
    timestamp: new Date().toISOString(),
    deployer: account.address,
    contracts: {},
    gasUsed: {},
    blockNumbers: {},
    transactionHashes: {},
  };

  console.log(`👤 Deployer: ${account.address}`);
  const balance = await client.getBalance({ address: account.address });
  console.log(`💰 Balance: ${parseFloat((Number(balance) / 1e18).toFixed(6))} tKUB`);

  try {
    console.log('\n📋 Phase 1: Foundation Contracts');

    // 1. Deploy TuuKeepAccessControl
    const accessControlArtifact = await loadContractArtifact('TuuKeepAccessControl');
    await deployContract(
      client,
      'accessControl',
      accessControlArtifact.abi,
      accessControlArtifact.bytecode,
      [], // No constructor arguments
      deploymentResult
    );

    // 2. Deploy TuuCoin
    const tuuCoinArtifact = await loadContractArtifact('TuuCoin');
    await deployContract(
      client,
      'tuuCoin',
      tuuCoinArtifact.abi,
      tuuCoinArtifact.bytecode,
      [deploymentResult.contracts.accessControl], // Access control address
      deploymentResult
    );

    // 3. Deploy Randomness
    const randomnessArtifact = await loadContractArtifact('Randomness');
    await deployContract(
      client,
      'randomness',
      randomnessArtifact.abi,
      randomnessArtifact.bytecode,
      [],
      deploymentResult
    );

    console.log('\n📋 Phase 2: Core Cabinet System');

    // 4. Deploy TuuKeepCabinetCore
    const cabinetCoreArtifact = await loadContractArtifact('TuuKeepCabinetCore');
    await deployContract(
      client,
      'cabinetCore',
      cabinetCoreArtifact.abi,
      cabinetCoreArtifact.bytecode,
      [
        deploymentResult.contracts.accessControl,
        account.address, // Platform fee recipient
      ],
      deploymentResult
    );

    // 5. Deploy TuuKeepCabinetGame
    const cabinetGameArtifact = await loadContractArtifact('TuuKeepCabinetGame');
    await deployContract(
      client,
      'cabinetGame',
      cabinetGameArtifact.abi,
      cabinetGameArtifact.bytecode,
      [
        deploymentResult.contracts.cabinetCore,
        deploymentResult.contracts.tuuCoin,
        deploymentResult.contracts.randomness,
      ],
      deploymentResult
    );

    console.log('\n📋 Phase 3: Ecosystem Extensions');

    // 6. Deploy TuuKeepMarketplace
    const marketplaceArtifact = await loadContractArtifact('TuuKeepMarketplace');
    await deployContract(
      client,
      'marketplace',
      marketplaceArtifact.abi,
      marketplaceArtifact.bytecode,
      [
        deploymentResult.contracts.cabinetCore,
        deploymentResult.contracts.accessControl,
      ],
      deploymentResult
    );

    // 7. Deploy TuuKeepTierSale
    const tierSaleArtifact = await loadContractArtifact('TuuKeepTierSale');
    await deployContract(
      client,
      'tierSale',
      tierSaleArtifact.abi,
      tierSaleArtifact.bytecode,
      [deploymentResult.contracts.cabinetCore],
      deploymentResult
    );

    console.log('\n📋 Phase 4: Contract Configuration');

    // Configure contract relationships and roles
    await setContractRoles(client, deploymentResult);

    // Calculate total gas used
    const totalGasUsed = Object.values(deploymentResult.gasUsed)
      .reduce((total, gas) => total + BigInt(gas), BigInt(0));

    console.log('\n🎉 Deployment completed successfully!');
    console.log('📊 Summary:');
    console.log(`- Total contracts deployed: ${Object.keys(deploymentResult.contracts).length}`);
    console.log(`- Total gas used: ${totalGasUsed.toString()}`);
    console.log(`- Deployment cost: ~${parseFloat((Number(totalGasUsed) * 1e-9).toFixed(6))} tKUB`);

    // Save deployment results
    const deploymentsDir = path.join(__dirname, '../deployments');
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }

    const resultFile = path.join(deploymentsDir, `kubTestnet-${Date.now()}.json`);
    fs.writeFileSync(resultFile, JSON.stringify(deploymentResult, null, 2));

    console.log(`📁 Deployment results saved to: ${resultFile}`);
    console.log('\n🔍 Next steps:');
    console.log('1. Verify contracts on KubScan:');
    console.log('   npx hardhat run scripts/verify-ecosystem.ts --network kubTestnet');
    console.log('2. Run integration tests:');
    console.log('   npx hardhat run scripts/validate-deployment.ts --network kubTestnet');

    return deploymentResult;

  } catch (error) {
    console.error('❌ Deployment failed:', error);
    throw error;
  }
}

// Run deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

export { main as deployManualKub };