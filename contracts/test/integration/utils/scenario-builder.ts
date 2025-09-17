import { parseEther } from "viem";
import { TestEnvironment, setupCabinetWithItems, setupCabinetWithTokens } from "./deployment-helper";
import { TEST_CABINET_CONFIGS, TEST_GACHA_PRICES } from "../fixtures/test-data";

export interface CabinetScenario {
  cabinetId: bigint;
  owner: `0x${string}`;
  tier: bigint;
  price: bigint;
  maxItems: bigint;
  itemCount: number;
}

export interface GachaScenario {
  cabinetId: bigint;
  player: `0x${string}`;
  paymentAmount: bigint;
  expectedOutcome: "win" | "lose" | "insufficient_payment" | "cabinet_empty";
}

export interface MarketplaceScenario {
  cabinetId: bigint;
  seller: `0x${string}`;
  buyer: `0x${string}`;
  listingPrice: bigint;
  expectedOutcome: "success" | "insufficient_funds" | "not_owner";
}

export class ScenarioBuilder {
  private environment: TestEnvironment;

  constructor(environment: TestEnvironment) {
    this.environment = environment;
  }

  async createBasicCabinetScenario(): Promise<CabinetScenario> {
    const { contracts, accounts } = this.environment;

    // Purchase cabinet from tier sale
    const tier = TEST_CABINET_CONFIGS.BASIC_CABINET.tier;
    const price = TEST_CABINET_CONFIGS.BASIC_CABINET.price;

    await contracts.tuuKeepTierSale.write.purchaseCabinet([tier], {
      account: accounts.CABINET_OWNER.address,
      value: price
    });

    const cabinetId = 1n; // First cabinet

    // Configure cabinet
    await contracts.tuuKeepCabinet.write.setCabinetPrice([
      cabinetId,
      TEST_GACHA_PRICES.CHEAP_PLAY
    ], { account: accounts.CABINET_OWNER.address });

    await contracts.tuuKeepCabinet.write.setMaxItems([
      cabinetId,
      TEST_CABINET_CONFIGS.BASIC_CABINET.maxItems
    ], { account: accounts.CABINET_OWNER.address });

    // Setup items
    await setupCabinetWithItems(this.environment, cabinetId, 5);

    return {
      cabinetId,
      owner: accounts.CABINET_OWNER.address,
      tier,
      price,
      maxItems: TEST_CABINET_CONFIGS.BASIC_CABINET.maxItems,
      itemCount: 5
    };
  }

  async createPremiumCabinetScenario(): Promise<CabinetScenario> {
    const { contracts, accounts } = this.environment;

    const tier = TEST_CABINET_CONFIGS.PREMIUM_CABINET.tier;
    const price = TEST_CABINET_CONFIGS.PREMIUM_CABINET.price;

    await contracts.tuuKeepTierSale.write.purchaseCabinet([tier], {
      account: accounts.CABINET_OWNER_2.address,
      value: price
    });

    const cabinetId = 2n; // Second cabinet

    await contracts.tuuKeepCabinet.write.setCabinetPrice([
      cabinetId,
      TEST_GACHA_PRICES.MEDIUM_PLAY
    ], { account: accounts.CABINET_OWNER_2.address });

    await contracts.tuuKeepCabinet.write.setMaxItems([
      cabinetId,
      TEST_CABINET_CONFIGS.PREMIUM_CABINET.maxItems
    ], { account: accounts.CABINET_OWNER_2.address });

    await setupCabinetWithItems(this.environment, cabinetId, 10);
    await setupCabinetWithTokens(this.environment, cabinetId, parseEther("50"));

    return {
      cabinetId,
      owner: accounts.CABINET_OWNER_2.address,
      tier,
      price,
      maxItems: TEST_CABINET_CONFIGS.PREMIUM_CABINET.maxItems,
      itemCount: 10
    };
  }

  async createSuccessfulGachaScenario(cabinetId: bigint): Promise<GachaScenario> {
    const { accounts } = this.environment;

    return {
      cabinetId,
      player: accounts.PLAYER_1.address,
      paymentAmount: TEST_GACHA_PRICES.CHEAP_PLAY,
      expectedOutcome: "win"
    };
  }

  async createFailedGachaScenario(cabinetId: bigint): Promise<GachaScenario> {
    const { accounts } = this.environment;

    return {
      cabinetId,
      player: accounts.PLAYER_2.address,
      paymentAmount: TEST_GACHA_PRICES.CHEAP_PLAY,
      expectedOutcome: "lose"
    };
  }

  async createInsufficientPaymentGachaScenario(cabinetId: bigint): Promise<GachaScenario> {
    const { accounts } = this.environment;

    return {
      cabinetId,
      player: accounts.PLAYER_3.address,
      paymentAmount: parseEther("0.005"), // Less than required
      expectedOutcome: "insufficient_payment"
    };
  }

  async createMarketplaceListingScenario(cabinetId: bigint): Promise<MarketplaceScenario> {
    const { contracts, accounts } = this.environment;

    const listingPrice = parseEther("0.2");

    // First approve marketplace to transfer cabinet
    await contracts.tuuKeepCabinet.write.approve([
      contracts.tuuKeepMarketplace.address,
      cabinetId
    ], { account: accounts.CABINET_OWNER.address });

    // Create listing
    await contracts.tuuKeepMarketplace.write.listItem([
      contracts.tuuKeepCabinet.address,
      cabinetId,
      listingPrice
    ], { account: accounts.CABINET_OWNER.address });

    return {
      cabinetId,
      seller: accounts.CABINET_OWNER.address,
      buyer: accounts.MARKETPLACE_BUYER.address,
      listingPrice,
      expectedOutcome: "success"
    };
  }

  async createInsufficientFundsMarketplaceScenario(cabinetId: bigint): Promise<MarketplaceScenario> {
    const { accounts } = this.environment;

    const highPrice = parseEther("1000"); // More than buyer has

    return {
      cabinetId,
      seller: accounts.CABINET_OWNER.address,
      buyer: accounts.MARKETPLACE_BUYER.address,
      listingPrice: highPrice,
      expectedOutcome: "insufficient_funds"
    };
  }

  async executeGachaScenario(scenario: GachaScenario): Promise<any> {
    const { contracts } = this.environment;

    try {
      const txHash = await contracts.tuuKeepCabinet.write.playGacha([scenario.cabinetId], {
        account: scenario.player,
        value: scenario.paymentAmount
      });

      return { success: true, txHash };
    } catch (error) {
      return { success: false, error };
    }
  }

  async executeMarketplaceScenario(scenario: MarketplaceScenario): Promise<any> {
    const { contracts } = this.environment;

    try {
      const txHash = await contracts.tuuKeepMarketplace.write.buyItem([
        contracts.tuuKeepCabinet.address,
        scenario.cabinetId
      ], {
        account: scenario.buyer,
        value: scenario.listingPrice
      });

      return { success: true, txHash };
    } catch (error) {
      return { success: false, error };
    }
  }

  async simulateConcurrentGachaPlays(cabinetId: bigint, playerCount: number = 3): Promise<any[]> {
    const { accounts } = this.environment;
    const players = [accounts.PLAYER_1, accounts.PLAYER_2, accounts.PLAYER_3];

    const scenarios: GachaScenario[] = players.slice(0, playerCount).map(player => ({
      cabinetId,
      player: player.address,
      paymentAmount: TEST_GACHA_PRICES.CHEAP_PLAY,
      expectedOutcome: "win" as const
    }));

    // Execute all scenarios concurrently
    const promises = scenarios.map(scenario => this.executeGachaScenario(scenario));
    const results = await Promise.allSettled(promises);

    return results.map((result, index) => ({
      player: scenarios[index].player,
      result: result.status === 'fulfilled' ? result.value : { success: false, error: result.reason }
    }));
  }
}