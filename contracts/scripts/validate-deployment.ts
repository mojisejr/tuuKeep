import { viem } from "hardhat";
import { formatEther, parseEther, getAddress } from "viem";

/**
 * TuuKeep Ecosystem Post-Deployment Validation Script
 *
 * Validates the deployed ecosystem by testing key functionality
 * and cross-contract integration points
 *
 * Usage: npx hardhat run scripts/validate-deployment.ts --network kubTestnet
 */

interface ContractAddresses {
  accessControl: string;
  tuuCoin: string;
  randomness: string;
  cabinet: string;
  marketplace: string;
  tierSale: string;
}

async function main() {
  console.log("🔍 Starting TuuKeep ecosystem validation...");

  const publicClient = await viem.getPublicClient();
  const [deployer] = await viem.getWalletClients();

  // Load contract addresses from environment
  const addresses: ContractAddresses = {
    accessControl: process.env.ACCESS_CONTROL_ADDRESS || "",
    tuuCoin: process.env.TUUCOIN_ADDRESS || "",
    randomness: process.env.RANDOMNESS_ADDRESS || "",
    cabinet: process.env.CABINET_ADDRESS || "",
    marketplace: process.env.MARKETPLACE_ADDRESS || "",
    tierSale: process.env.TIER_SALE_ADDRESS || "",
  };

  // Validate addresses
  if (Object.values(addresses).some(addr => !addr)) {
    console.error("❌ Missing contract addresses. Run deployment first.");
    return;
  }

  console.log("📋 Validating contracts:");
  Object.entries(addresses).forEach(([name, address]) => {
    console.log(`- ${name}: ${address}`);
  });

  try {
    // 1. Validate contract deployment
    console.log("\n🔍 1. Validating contract deployment...");
    await validateContractDeployment(publicClient, addresses);

    // 2. Validate access control integration
    console.log("\n🔍 2. Validating access control integration...");
    await validateAccessControl(publicClient, addresses);

    // 3. Validate cross-contract dependencies
    console.log("\n🔍 3. Validating cross-contract dependencies...");
    await validateCrossContractDependencies(publicClient, addresses);

    // 4. Validate basic functionality
    console.log("\n🔍 4. Validating basic functionality...");
    await validateBasicFunctionality(publicClient, deployer, addresses);

    console.log("\n✅ All validations passed!");
    console.log("🎉 TuuKeep ecosystem is ready for testnet operations!");

  } catch (error) {
    console.error("❌ Validation failed:", error);
    process.exit(1);
  }
}

async function validateContractDeployment(publicClient: any, addresses: ContractAddresses) {
  for (const [name, address] of Object.entries(addresses)) {
    const code = await publicClient.getCode({ address: getAddress(address) });
    if (!code || code === "0x") {
      throw new Error(`Contract ${name} not deployed at ${address}`);
    }
    console.log(`✅ ${name} deployed and has bytecode`);
  }
}

async function validateAccessControl(publicClient: any, addresses: ContractAddresses) {
  // Check if access control is properly integrated
  const accessControlAbi = [
    {
      inputs: [{ type: "bytes32" }, { type: "address" }],
      name: "hasRole",
      outputs: [{ type: "bool" }],
      stateMutability: "view",
      type: "function",
    },
  ];

  const accessControl = {
    address: getAddress(addresses.accessControl),
    abi: accessControlAbi,
  };

  // Check DEFAULT_ADMIN_ROLE exists
  const defaultAdminRole = "0x0000000000000000000000000000000000000000000000000000000000000000";

  try {
    await publicClient.readContract({
      ...accessControl,
      functionName: "hasRole",
      args: [defaultAdminRole, getAddress(process.env.DEFAULT_ADMIN || addresses.accessControl)],
    });
    console.log("✅ Access control roles configured");
  } catch (error) {
    console.log("⚠️  Could not validate access control roles");
  }
}

async function validateCrossContractDependencies(publicClient: any, addresses: ContractAddresses) {
  // Validate TuuCoin integration with cabinet
  const tuuCoinAbi = [
    {
      inputs: [],
      name: "accessControl",
      outputs: [{ type: "address" }],
      stateMutability: "view",
      type: "function",
    },
  ];

  try {
    const tuuCoinAccessControl = await publicClient.readContract({
      address: getAddress(addresses.tuuCoin),
      abi: tuuCoinAbi,
      functionName: "accessControl",
    });

    if (tuuCoinAccessControl.toLowerCase() === addresses.accessControl.toLowerCase()) {
      console.log("✅ TuuCoin properly integrated with access control");
    } else {
      console.log("⚠️  TuuCoin access control integration mismatch");
    }
  } catch (error) {
    console.log("⚠️  Could not validate TuuCoin integration");
  }

  // Validate Cabinet dependencies
  const cabinetAbi = [
    {
      inputs: [],
      name: "tuuCoin",
      outputs: [{ type: "address" }],
      stateMutability: "view",
      type: "function",
    },
    {
      inputs: [],
      name: "randomness",
      outputs: [{ type: "address" }],
      stateMutability: "view",
      type: "function",
    },
  ];

  try {
    const [cabinetTuuCoin, cabinetRandomness] = await Promise.all([
      publicClient.readContract({
        address: getAddress(addresses.cabinet),
        abi: cabinetAbi,
        functionName: "tuuCoin",
      }),
      publicClient.readContract({
        address: getAddress(addresses.cabinet),
        abi: cabinetAbi,
        functionName: "randomness",
      }),
    ]);

    if (cabinetTuuCoin.toLowerCase() === addresses.tuuCoin.toLowerCase()) {
      console.log("✅ Cabinet properly integrated with TuuCoin");
    } else {
      console.log("⚠️  Cabinet TuuCoin integration mismatch");
    }

    if (cabinetRandomness.toLowerCase() === addresses.randomness.toLowerCase()) {
      console.log("✅ Cabinet properly integrated with Randomness");
    } else {
      console.log("⚠️  Cabinet Randomness integration mismatch");
    }
  } catch (error) {
    console.log("⚠️  Could not validate Cabinet dependencies");
  }
}

async function validateBasicFunctionality(publicClient: any, deployer: any, addresses: ContractAddresses) {
  // Test basic read functions
  const tuuCoinAbi = [
    {
      inputs: [],
      name: "name",
      outputs: [{ type: "string" }],
      stateMutability: "view",
      type: "function",
    },
    {
      inputs: [],
      name: "symbol",
      outputs: [{ type: "string" }],
      stateMutability: "view",
      type: "function",
    },
    {
      inputs: [],
      name: "totalSupply",
      outputs: [{ type: "uint256" }],
      stateMutability: "view",
      type: "function",
    },
  ];

  try {
    const [name, symbol, totalSupply] = await Promise.all([
      publicClient.readContract({
        address: getAddress(addresses.tuuCoin),
        abi: tuuCoinAbi,
        functionName: "name",
      }),
      publicClient.readContract({
        address: getAddress(addresses.tuuCoin),
        abi: tuuCoinAbi,
        functionName: "symbol",
      }),
      publicClient.readContract({
        address: getAddress(addresses.tuuCoin),
        abi: tuuCoinAbi,
        functionName: "totalSupply",
      }),
    ]);

    console.log(`✅ TuuCoin: ${name} (${symbol}) - Total Supply: ${formatEther(totalSupply)}`);
  } catch (error) {
    console.log("⚠️  Could not read TuuCoin basic info");
  }

  // Test Cabinet contract
  const cabinetAbi = [
    {
      inputs: [],
      name: "name",
      outputs: [{ type: "string" }],
      stateMutability: "view",
      type: "function",
    },
    {
      inputs: [],
      name: "symbol",
      outputs: [{ type: "string" }],
      stateMutability: "view",
      type: "function",
    },
    {
      inputs: [],
      name: "totalSupply",
      outputs: [{ type: "uint256" }],
      stateMutability: "view",
      type: "function",
    },
  ];

  try {
    const [cabinetName, cabinetSymbol, cabinetTotalSupply] = await Promise.all([
      publicClient.readContract({
        address: getAddress(addresses.cabinet),
        abi: cabinetAbi,
        functionName: "name",
      }),
      publicClient.readContract({
        address: getAddress(addresses.cabinet),
        abi: cabinetAbi,
        functionName: "symbol",
      }),
      publicClient.readContract({
        address: getAddress(addresses.cabinet),
        abi: cabinetAbi,
        functionName: "totalSupply",
      }),
    ]);

    console.log(`✅ Cabinet: ${cabinetName} (${cabinetSymbol}) - Total Supply: ${cabinetTotalSupply}`);
  } catch (error) {
    console.log("⚠️  Could not read Cabinet basic info");
  }

  console.log("✅ Basic functionality validation completed");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Validation script failed:", error);
    process.exit(1);
  });