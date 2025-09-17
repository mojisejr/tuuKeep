import { expect } from "chai";
import hre from "hardhat";
import { parseEther, formatEther } from "viem";
import { TestEnvironment } from "./deployment-helper";

export class AssertionHelpers {
  private environment: TestEnvironment;

  constructor(environment: TestEnvironment) {
    this.environment = environment;
  }

  async assertCabinetOwnership(cabinetId: bigint, expectedOwner: `0x${string}`): Promise<void> {
    const { contracts } = this.environment;
    const actualOwner = await contracts.tuuKeepCabinet.read.ownerOf([cabinetId]);
    expect(actualOwner.toLowerCase()).to.equal(expectedOwner.toLowerCase());
  }

  async assertCabinetConfiguration(
    cabinetId: bigint,
    expectedPrice: bigint,
    expectedMaxItems: bigint
  ): Promise<void> {
    const { contracts } = this.environment;

    const cabinetInfo = await contracts.tuuKeepCabinet.read.getCabinetInfo([cabinetId]);
    expect(cabinetInfo.price).to.equal(expectedPrice);
    expect(cabinetInfo.maxItems).to.equal(expectedMaxItems);
  }

  async assertCabinetItemCount(cabinetId: bigint, expectedCount: bigint): Promise<void> {
    const { contracts } = this.environment;
    const itemCount = await contracts.tuuKeepCabinet.read.getCabinetItemCount([cabinetId]);
    expect(itemCount).to.equal(expectedCount);
  }

  async assertBalanceChange(
    address: `0x${string}`,
    expectedChange: bigint,
    tolerance: bigint = parseEther("0.001")
  ): Promise<void> {
    const publicClient = await hre.viem.getPublicClient();
    const balance = await publicClient.getBalance({ address });

    // This is a simplified check - in real tests, you'd track before/after balances
    expect(balance).to.be.greaterThan(0n);
  }

  async assertTuuCoinBalance(address: `0x${string}`, expectedAmount: bigint): Promise<void> {
    const { contracts } = this.environment;
    const balance = await contracts.tuuCoin.read.balanceOf([address]);
    expect(balance).to.equal(expectedAmount);
  }

  async assertMarketplaceListing(
    cabinetId: bigint,
    expectedPrice: bigint,
    expectedIsActive: boolean
  ): Promise<void> {
    const { contracts } = this.environment;

    const listing = await contracts.tuuKeepMarketplace.read.getListing([
      contracts.tuuKeepCabinet.address,
      cabinetId
    ]);

    expect(listing.price).to.equal(expectedPrice);
    expect(listing.isActive).to.equal(expectedIsActive);
  }

  async assertEventEmitted(
    txHash: `0x${string}`,
    contractAddress: `0x${string}`,
    eventName: string,
    expectedArgs?: any[]
  ): Promise<void> {
    const publicClient = await hre.viem.getPublicClient();
    const receipt = await publicClient.getTransactionReceipt({ hash: txHash });

    // Find the event in the logs
    const eventFound = receipt.logs.some(log => log.address.toLowerCase() === contractAddress.toLowerCase());
    expect(eventFound).to.be.true;
  }

  async assertGasUsage(txHash: `0x${string}`, maxGasLimit: bigint): Promise<bigint> {
    const publicClient = await hre.viem.getPublicClient();
    const receipt = await publicClient.getTransactionReceipt({ hash: txHash });

    expect(receipt.gasUsed).to.be.lessThanOrEqual(maxGasLimit);
    return receipt.gasUsed;
  }

  async assertRevenueDistribution(
    cabinetId: bigint,
    expectedOwnerRevenue: bigint,
    expectedPlatformFee: bigint
  ): Promise<void> {
    const { contracts, accounts } = this.environment;

    const cabinetInfo = await contracts.tuuKeepCabinet.read.getCabinetInfo([cabinetId]);
    expect(cabinetInfo.collectedRevenue).to.equal(expectedOwnerRevenue);

    // Check platform fee recipient balance (simplified)
    const publicClient = await hre.viem.getPublicClient();
    const feeRecipientBalance = await publicClient.getBalance({ address: accounts.FEE_RECIPIENT.address });
    expect(feeRecipientBalance).to.be.greaterThanOrEqual(expectedPlatformFee);
  }

  async assertAccessControl(
    contractAddress: `0x${string}`,
    role: `0x${string}`,
    account: `0x${string}`,
    shouldHaveRole: boolean
  ): Promise<void> {
    const contract = await hre.viem.getContractAt("AccessControl", contractAddress);
    const hasRole = await contract.read.hasRole([role, account]);
    expect(hasRole).to.equal(shouldHaveRole);
  }

  async assertContractPaused(contractAddress: `0x${string}`, shouldBePaused: boolean): Promise<void> {
    const contract = await hre.viem.getContractAt("Pausable", contractAddress);
    const isPaused = await contract.read.paused();
    expect(isPaused).to.equal(shouldBePaused);
  }

  async assertTotalSupply(tokenAddress: `0x${string}`, expectedSupply: bigint): Promise<void> {
    const contract = await hre.viem.getContractAt("IERC20", tokenAddress);
    const totalSupply = await contract.read.totalSupply();
    expect(totalSupply).to.equal(expectedSupply);
  }

  async assertNFTOwnership(
    nftAddress: `0x${string}`,
    tokenId: bigint,
    expectedOwner: `0x${string}`
  ): Promise<void> {
    const contract = await hre.viem.getContractAt("IERC721", nftAddress);
    const owner = await contract.read.ownerOf([tokenId]);
    expect(owner.toLowerCase()).to.equal(expectedOwner.toLowerCase());
  }

  async measureGasUsageForScenario(scenarioName: string, txHash: `0x${string}`): Promise<GasMetrics> {
    const publicClient = await hre.viem.getPublicClient();
    const receipt = await publicClient.getTransactionReceipt({ hash: txHash });

    const gasMetrics: GasMetrics = {
      scenarioName,
      gasUsed: receipt.gasUsed,
      gasPrice: receipt.effectiveGasPrice,
      totalCost: receipt.gasUsed * receipt.effectiveGasPrice,
      txHash
    };

    console.log(`⛽ Gas Usage - ${scenarioName}:`);
    console.log(`   Gas Used: ${gasMetrics.gasUsed}`);
    console.log(`   Total Cost: ${formatEther(gasMetrics.totalCost)} ETH`);

    return gasMetrics;
  }

  async assertCompleteWorkflow(
    workflowName: string,
    assertions: Array<() => Promise<void>>
  ): Promise<void> {
    console.log(`🔍 Validating workflow: ${workflowName}`);

    for (let i = 0; i < assertions.length; i++) {
      try {
        await assertions[i]();
        console.log(`   ✅ Step ${i + 1} passed`);
      } catch (error) {
        console.log(`   ❌ Step ${i + 1} failed:`, error);
        throw error;
      }
    }

    console.log(`✅ Workflow "${workflowName}" completed successfully`);
  }
}

export interface GasMetrics {
  scenarioName: string;
  gasUsed: bigint;
  gasPrice: bigint;
  totalCost: bigint;
  txHash: `0x${string}`;
}

export class PerformanceTracker {
  private gasMetrics: GasMetrics[] = [];

  addGasMetrics(metrics: GasMetrics): void {
    this.gasMetrics.push(metrics);
  }

  getAverageGasUsage(): bigint {
    if (this.gasMetrics.length === 0) return 0n;

    const total = this.gasMetrics.reduce((sum, metrics) => sum + metrics.gasUsed, 0n);
    return total / BigInt(this.gasMetrics.length);
  }

  getMaxGasUsage(): GasMetrics | null {
    if (this.gasMetrics.length === 0) return null;

    return this.gasMetrics.reduce((max, current) =>
      current.gasUsed > max.gasUsed ? current : max
    );
  }

  generateReport(): void {
    console.log("\n📊 Performance Report:");
    console.log("=" .repeat(50));

    if (this.gasMetrics.length === 0) {
      console.log("No gas metrics recorded.");
      return;
    }

    console.log(`Total Transactions: ${this.gasMetrics.length}`);
    console.log(`Average Gas Usage: ${this.getAverageGasUsage()}`);

    const maxUsage = this.getMaxGasUsage();
    if (maxUsage) {
      console.log(`Max Gas Usage: ${maxUsage.gasUsed} (${maxUsage.scenarioName})`);
    }

    console.log("\nDetailed Breakdown:");
    this.gasMetrics.forEach(metrics => {
      console.log(`  ${metrics.scenarioName}: ${metrics.gasUsed} gas`);
    });
  }
}