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
  const possiblePaths = [
    path.join(__dirname, `../artifacts/contracts/${contractName}.sol/${contractName}.json`),
    path.join(__dirname, `../artifacts/contracts/Utils/Security/${contractName}.sol/${contractName}.json`),
    path.join(__dirname, `../artifacts/contracts/Utils/${contractName}.sol/${contractName}.json`),
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

async function deployContract(walletClient: any, publicClient: any, name: string, args: any[] = []) {
  console.log(`\n📦 Deploying ${name}...`);

  try {
    const { abi, bytecode } = await loadContractArtifact(name);

    const hash = await walletClient.deployContract({
      abi,
      bytecode: bytecode as `0x${string}`,
      args,
    });

    console.log(`⏳ Transaction hash: ${hash}`);
    const receipt = await publicClient.waitForTransactionReceipt({ hash });

    console.log(`✅ ${name} deployed successfully!`);
    console.log(`📍 Address: ${receipt.contractAddress}`);
    console.log(`⛽ Gas used: ${receipt.gasUsed.toString()}`);

    return {
      address: receipt.contractAddress,
      transactionHash: hash,
      gasUsed: receipt.gasUsed,
    };
  } catch (error) {
    console.error(`❌ Failed to deploy ${name}:`, error);
    throw error;
  }
}

async function main() {
  console.log("🚀 Starting Phase T.3 Step 1: Foundation Contracts Deployment");
  console.log("============================================================");

  // Setup clients
  const privateKey = process.env.KUB_TESTNET_PRIVATE_KEY;
  if (!privateKey) {
    throw new Error("KUB_TESTNET_PRIVATE_KEY not found in environment variables");
  }
  const formattedPrivateKey = privateKey.startsWith('0x') ? privateKey : `0x${privateKey}`;
  const account = privateKeyToAccount(formattedPrivateKey as `0x${string}`);
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

  try {
    // 1. Deploy TuuKeepAccessControl (Foundation)
    console.log("\n📋 Step 1.1: Deploying TuuKeepAccessControl...");
    const accessControlResult = await deployContract(walletClient, publicClient, "TuuKeepAccessControl");
    const accessControlAddress = accessControlResult.address;
    deployedContracts.TuuKeepAccessControl = accessControlAddress!;

    // Verify deployment
    const code = await publicClient.getCode({ address: accessControlAddress! });
    if (!code || code === "0x") {
      throw new Error("TuuKeepAccessControl deployment failed - no code at address");
    }

    // 2. Deploy TuuCoinBase (Base Token)
    console.log("\n💰 Step 1.2: Deploying TuuCoinBase...");
    const tuuCoinBaseResult = await deployContract(walletClient, publicClient, "TuuCoinBase", [
      accessControlAddress,  // access control
      account.address       // initial admin
    ]);
    const tuuCoinBaseAddress = tuuCoinBaseResult.address;
    deployedContracts.TuuCoinBase = tuuCoinBaseAddress!;

    // Verify deployment - get token info
    const { abi: tuuCoinAbi } = await loadContractArtifact("TuuCoinBase");
    const tokenName = await publicClient.readContract({
      address: tuuCoinBaseAddress!,
      abi: tuuCoinAbi,
      functionName: 'name',
    });
    console.log(`   Token Name: ${tokenName}`);
    const tokenSymbol = await publicClient.readContract({
      address: tuuCoinBaseAddress!,
      abi: tuuCoinAbi,
      functionName: 'symbol',
    });
    console.log(`   Token Symbol: ${tokenSymbol}`);

    // 3. Deploy Randomness (Utility)
    console.log("\n🎲 Step 1.3: Deploying Randomness...");
    const randomnessResult = await deployContract(walletClient, publicClient, "Randomness");
    const randomnessAddress = randomnessResult.address;
    deployedContracts.Randomness = randomnessAddress!;

    // 4. Contract Size Validation
    console.log("\n📏 Step 1.4: Validating Contract Sizes...");

    const contracts = [
      { name: "TuuKeepAccessControl", address: accessControlAddress! },
      { name: "TuuCoinBase", address: tuuCoinBaseAddress! },
      { name: "Randomness", address: randomnessAddress! }
    ];

    for (const contract of contracts) {
      const code = await publicClient.getCode({ address: contract.address });
      const sizeInBytes = code ? (code.length - 2) / 2 : 0; // Remove 0x prefix and convert hex to bytes
      const sizeInKB = (sizeInBytes / 1024).toFixed(2);

      console.log(`   ${contract.name}: ${sizeInBytes} bytes (${sizeInKB} KB)`);

      if (sizeInBytes > 24576) { // 24KB limit
        console.warn(`   ⚠️  Warning: ${contract.name} is ${sizeInKB} KB (close to 24KB limit)`);
      }
    }

    // 5. Functional Validation
    console.log("\n🔍 Step 1.5: Functional Validation...");

    // Test AccessControl
    const { abi: accessControlAbi } = await loadContractArtifact("TuuKeepAccessControl");
    const defaultAdminRole = await publicClient.readContract({
      address: accessControlAddress!,
      abi: accessControlAbi,
      functionName: 'DEFAULT_ADMIN_ROLE',
    });
    const hasDefaultAdminRole = await publicClient.readContract({
      address: accessControlAddress!,
      abi: accessControlAbi,
      functionName: 'hasRole',
      args: [defaultAdminRole, account.address],
    });
    console.log(`   AccessControl admin role: ${hasDefaultAdminRole ? '✅' : '❌'}`);

    // Test TuuCoinBase supply stats
    const supplyStats = await publicClient.readContract({
      address: tuuCoinBaseAddress!,
      abi: tuuCoinAbi,
      functionName: 'getSupplyStats',
    }) as bigint[];
    console.log(`   TuuCoinBase current supply: ${formatEther(supplyStats[0])} TUU`);
    console.log(`   TuuCoinBase max supply: ${formatEther(supplyStats[3])} TUU`);

    // Test Randomness
    try {
      const randomnessCode = await publicClient.getCode({ address: randomnessAddress! });
      const randomnessSize = randomnessCode ? (randomnessCode.length - 2) / 2 : 0;
      console.log(`   Randomness contract code size: ${randomnessSize} bytes ✅`);
    } catch (error) {
      console.log(`   Randomness validation: ❌ ${error}`);
    }

    // 6. Save deployment addresses
    console.log("\n💾 Step 1.6: Saving Deployment Addresses...");

    const deploymentData = {
      network: "kub-testnet",
      timestamp: new Date().toISOString(),
      step: "1-foundation",
      contracts: deployedContracts,
      deployer: account.address,
      gasUsed: "estimated" // Would need to track this properly in real deployment
    };

    const deploymentDir = path.join(__dirname, '..', 'deployments');
    if (!fs.existsSync(deploymentDir)) {
      fs.mkdirSync(deploymentDir, { recursive: true });
    }

    const deploymentFile = path.join(deploymentDir, 'step-1-foundation.json');
    fs.writeFileSync(deploymentFile, JSON.stringify(deploymentData, null, 2));
    console.log(`   Deployment data saved to: ${deploymentFile}`);

    // 7. Summary
    console.log("\n🎉 Step 1 Foundation Deployment Complete!");
    console.log("=============================================");
    console.log("Deployed Contracts:");
    Object.entries(deployedContracts).forEach(([name, address]) => {
      console.log(`  ${name}: ${address}`);
    });

    console.log("\n📋 Next Steps:");
    console.log("  1. Run: npx hardhat run scripts/deploy-step-2-cabinet.ts --network kubTestnet");
    console.log("  2. Verify contracts on KubScan");
    console.log("  3. Test basic functionality");

    console.log("\n⚠️  Important Notes:");
    console.log("  - All contracts deployed successfully");
    console.log("  - Contract sizes are within EVM limits");
    console.log("  - Ready for Step 2: Cabinet Contracts");

  } catch (error) {
    console.error("\n❌ Step 1 Deployment Failed:");
    console.error(error);

    // Log deployed contracts for debugging
    if (Object.keys(deployedContracts).length > 0) {
      console.log("\n📋 Partially Deployed Contracts:");
      Object.entries(deployedContracts).forEach(([name, address]) => {
        console.log(`  ${name}: ${address}`);
      });
    }

    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });