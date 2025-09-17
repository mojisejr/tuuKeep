import hre from "hardhat";
import { parseEther, getAddress } from "viem";
import { TEST_ACCOUNTS, getAllTestAccounts } from "../fixtures/test-accounts";
import { TEST_FEE_CONFIG } from "../fixtures/test-data";

export interface DeployedContracts {
  tuuKeepCabinet: any;
  tuuCoin: any;
  tuuKeepMarketplace: any;
  tuuKeepTierSale: any;
  mockERC721: any;
  mockERC20: any;
}

export interface TestEnvironment {
  contracts: DeployedContracts;
  accounts: typeof TEST_ACCOUNTS;
  wallets: any;
}

export async function deployTestEnvironment(): Promise<TestEnvironment> {
  console.log("🚀 Deploying test environment...");

  // Get signers for test accounts
  const [deployer, ...testSigners] = await hre.viem.getWalletClients();

  // Fund test accounts
  const publicClient = await hre.viem.getPublicClient();

  console.log("💰 Funding test accounts...");
  for (const account of getAllTestAccounts()) {
    const balance = await publicClient.getBalance({ address: account.address });
    if (balance < account.initialBalance) {
      // In real test, we'd fund these accounts
      // For now, we'll use the default Hardhat accounts
    }
  }

  // Deploy mock contracts first (for testing purposes)
  console.log("📦 Deploying mock contracts...");

  const mockERC721 = await hre.viem.deployContract("MockERC721", ["Test NFT", "TNFT"]);
  const mockERC20 = await hre.viem.deployContract("MockERC20", ["Test Token", "TT", parseEther("1000000")]);

  // Deploy TuuCoin contract
  console.log("🪙 Deploying TuuCoin contract...");
  const tuuCoin = await hre.viem.deployContract("TuuCoin", [
    TEST_ACCOUNTS.PLATFORM_ADMIN.address,
    TEST_ACCOUNTS.PLATFORM_ADMIN.address
  ]);

  // Deploy TuuKeepCabinet contract
  console.log("🏪 Deploying TuuKeepCabinet contract...");
  const tuuKeepCabinet = await hre.viem.deployContract("TuuKeepCabinet", [
    TEST_ACCOUNTS.PLATFORM_ADMIN.address,
    TEST_ACCOUNTS.FEE_RECIPIENT.address,
    tuuCoin.address,
    TEST_FEE_CONFIG.PLATFORM_FEE_RATE
  ]);

  // Deploy TuuKeepMarketplace contract
  console.log("🛒 Deploying TuuKeepMarketplace contract...");
  const tuuKeepMarketplace = await hre.viem.deployContract("TuuKeepMarketplace", [
    TEST_ACCOUNTS.PLATFORM_ADMIN.address,
    TEST_ACCOUNTS.FEE_RECIPIENT.address,
    TEST_FEE_CONFIG.MARKETPLACE_FEE_RATE
  ]);

  // Deploy TuuKeepTierSale contract
  console.log("🎟️ Deploying TuuKeepTierSale contract...");
  const tuuKeepTierSale = await hre.viem.deployContract("TuuKeepTierSale", [
    TEST_ACCOUNTS.PLATFORM_ADMIN.address,
    tuuKeepCabinet.address,
    TEST_ACCOUNTS.FEE_RECIPIENT.address
  ]);

  // Setup contract permissions and connections
  console.log("🔗 Setting up contract permissions...");

  // Grant minter role to TuuKeepCabinet for TuuCoin
  await tuuCoin.write.grantRole([
    await tuuCoin.read.MINTER_ROLE(),
    tuuKeepCabinet.address
  ], { account: TEST_ACCOUNTS.PLATFORM_ADMIN.address });

  // Grant minter role to TuuKeepTierSale for TuuKeepCabinet
  await tuuKeepCabinet.write.grantRole([
    await tuuKeepCabinet.read.MINTER_ROLE(),
    tuuKeepTierSale.address
  ], { account: TEST_ACCOUNTS.PLATFORM_ADMIN.address });

  // Register cabinet contract with TuuCoin
  await tuuCoin.write.registerCabinet([
    tuuKeepCabinet.address,
    10n // 10 TuuCoins per failed gacha
  ], { account: TEST_ACCOUNTS.PLATFORM_ADMIN.address });

  // Setup marketplace to work with cabinets
  await tuuKeepMarketplace.write.setApprovedCollection([
    tuuKeepCabinet.address,
    true
  ], { account: TEST_ACCOUNTS.PLATFORM_ADMIN.address });

  console.log("✅ Test environment deployed successfully!");

  const wallets = {
    deployer,
    platformAdmin: testSigners[0],
    cabinetOwner: testSigners[1],
    cabinetOwner2: testSigners[2],
    player1: testSigners[3],
    player2: testSigners[4],
    player3: testSigners[5],
    marketplaceBuyer: testSigners[6],
    marketplaceSeller: testSigners[7],
    feeRecipient: testSigners[8],
    emergencyResponder: testSigners[9]
  };

  return {
    contracts: {
      tuuKeepCabinet,
      tuuCoin,
      tuuKeepMarketplace,
      tuuKeepTierSale,
      mockERC721,
      mockERC20
    },
    accounts: TEST_ACCOUNTS,
    wallets
  };
}

export async function setupCabinetWithItems(
  environment: TestEnvironment,
  cabinetId: bigint,
  itemCount: number = 5
): Promise<void> {
  const { contracts, accounts, wallets } = environment;

  console.log(`🎁 Setting up cabinet ${cabinetId} with ${itemCount} items...`);

  // Mint NFTs to cabinet owner
  for (let i = 0; i < itemCount; i++) {
    await contracts.mockERC721.write.mint([
      accounts.CABINET_OWNER.address,
      BigInt(i + 1)
    ]);

    // Approve cabinet contract to manage the NFT
    await contracts.mockERC721.write.approve([
      contracts.tuuKeepCabinet.address,
      BigInt(i + 1)
    ], { account: accounts.CABINET_OWNER.address });

    // Deposit NFT into cabinet
    await contracts.tuuKeepCabinet.write.depositERC721([
      cabinetId,
      contracts.mockERC721.address,
      BigInt(i + 1)
    ], { account: accounts.CABINET_OWNER.address });
  }

  console.log(`✅ Cabinet ${cabinetId} setup complete with ${itemCount} NFTs`);
}

export async function setupCabinetWithTokens(
  environment: TestEnvironment,
  cabinetId: bigint,
  tokenAmount: bigint = parseEther("100")
): Promise<void> {
  const { contracts, accounts } = environment;

  console.log(`💰 Setting up cabinet ${cabinetId} with ${tokenAmount} tokens...`);

  // Transfer tokens to cabinet owner
  await contracts.mockERC20.write.transfer([
    accounts.CABINET_OWNER.address,
    tokenAmount
  ]);

  // Approve cabinet contract to manage tokens
  await contracts.mockERC20.write.approve([
    contracts.tuuKeepCabinet.address,
    tokenAmount
  ], { account: accounts.CABINET_OWNER.address });

  // Deposit tokens into cabinet
  await contracts.tuuKeepCabinet.write.depositERC20([
    cabinetId,
    contracts.mockERC20.address,
    tokenAmount
  ], { account: accounts.CABINET_OWNER.address });

  console.log(`✅ Cabinet ${cabinetId} setup complete with tokens`);
}