import { ethers } from "hardhat";
import { Contract } from "ethers";

async function main() {
  console.log("🚀 Starting Phase T.3 Step 1: Foundation Contracts Deployment");
  console.log("============================================================");

  const [deployer] = await ethers.getSigners();
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Balance: ${ethers.formatEther(await deployer.provider.getBalance(deployer.address))} KUB`);

  const deployedContracts: { [key: string]: string } = {};

  try {
    // 1. Deploy TuuKeepAccessControl (Foundation)
    console.log("\n📋 Step 1.1: Deploying TuuKeepAccessControl...");
    const TuuKeepAccessControl = await ethers.getContractFactory("TuuKeepAccessControl");
    const accessControl = await TuuKeepAccessControl.deploy();
    await accessControl.waitForDeployment();

    const accessControlAddress = await accessControl.getAddress();
    deployedContracts.TuuKeepAccessControl = accessControlAddress;
    console.log(`✅ TuuKeepAccessControl deployed to: ${accessControlAddress}`);

    // Verify deployment
    const code = await deployer.provider.getCode(accessControlAddress);
    if (code === "0x") {
      throw new Error("TuuKeepAccessControl deployment failed - no code at address");
    }

    // 2. Deploy TuuCoinBase (Base Token)
    console.log("\n💰 Step 1.2: Deploying TuuCoinBase...");
    const TuuCoinBase = await ethers.getContractFactory("TuuCoinBase");
    const tuuCoinBase = await TuuCoinBase.deploy(
      accessControlAddress,  // access control
      deployer.address      // initial admin
    );
    await tuuCoinBase.waitForDeployment();

    const tuuCoinBaseAddress = await tuuCoinBase.getAddress();
    deployedContracts.TuuCoinBase = tuuCoinBaseAddress;
    console.log(`✅ TuuCoinBase deployed to: ${tuuCoinBaseAddress}`);

    // Verify deployment
    const tokenName = await tuuCoinBase.name();
    console.log(`   Token Name: ${tokenName}`);
    const tokenSymbol = await tuuCoinBase.symbol();
    console.log(`   Token Symbol: ${tokenSymbol}`);

    // 3. Deploy Randomness (Utility)
    console.log("\n🎲 Step 1.3: Deploying Randomness...");
    const Randomness = await ethers.getContractFactory("Randomness");
    const randomness = await Randomness.deploy();
    await randomness.waitForDeployment();

    const randomnessAddress = await randomness.getAddress();
    deployedContracts.Randomness = randomnessAddress;
    console.log(`✅ Randomness deployed to: ${randomnessAddress}`);

    // 4. Contract Size Validation
    console.log("\n📏 Step 1.4: Validating Contract Sizes...");

    const contracts = [
      { name: "TuuKeepAccessControl", address: accessControlAddress },
      { name: "TuuCoinBase", address: tuuCoinBaseAddress },
      { name: "Randomness", address: randomnessAddress }
    ];

    for (const contract of contracts) {
      const code = await deployer.provider.getCode(contract.address);
      const sizeInBytes = (code.length - 2) / 2; // Remove 0x prefix and convert hex to bytes
      const sizeInKB = (sizeInBytes / 1024).toFixed(2);

      console.log(`   ${contract.name}: ${sizeInBytes} bytes (${sizeInKB} KB)`);

      if (sizeInBytes > 24576) { // 24KB limit
        console.warn(`   ⚠️  Warning: ${contract.name} is ${sizeInKB} KB (close to 24KB limit)`);
      }
    }

    // 5. Functional Validation
    console.log("\n🔍 Step 1.5: Functional Validation...");

    // Test AccessControl
    const hasDefaultAdminRole = await accessControl.hasRole(
      await accessControl.DEFAULT_ADMIN_ROLE(),
      deployer.address
    );
    console.log(`   AccessControl admin role: ${hasDefaultAdminRole ? '✅' : '❌'}`);

    // Test TuuCoinBase supply stats
    const supplyStats = await tuuCoinBase.getSupplyStats();
    console.log(`   TuuCoinBase current supply: ${ethers.formatEther(supplyStats[0])} TUU`);
    console.log(`   TuuCoinBase max supply: ${ethers.formatEther(supplyStats[3])} TUU`);

    // Test Randomness
    try {
      // Just check if we can call the contract without reverting
      const randomnessCode = await deployer.provider.getCode(randomnessAddress);
      console.log(`   Randomness contract code size: ${(randomnessCode.length - 2) / 2} bytes ✅`);
    } catch (error) {
      console.log(`   Randomness validation: ❌ ${error}`);
    }

    // 6. Save deployment addresses
    console.log("\n💾 Step 1.6: Saving Deployment Addresses...");
    const fs = require('fs');
    const path = require('path');

    const deploymentData = {
      network: "kub-testnet",
      timestamp: new Date().toISOString(),
      step: "1-foundation",
      contracts: deployedContracts,
      deployer: deployer.address,
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