import { parseEther, parseUnits } from "viem";

export const TEST_CABINET_CONFIGS = {
  BASIC_CABINET: {
    tier: 1n,
    price: parseEther("0.1"),
    maxItems: 100n,
    name: "Basic Test Cabinet",
    description: "A basic cabinet for testing"
  },

  PREMIUM_CABINET: {
    tier: 2n,
    price: parseEther("0.5"),
    maxItems: 500n,
    name: "Premium Test Cabinet",
    description: "A premium cabinet for testing"
  },

  LUXURY_CABINET: {
    tier: 3n,
    price: parseEther("1.0"),
    maxItems: 1000n,
    name: "Luxury Test Cabinet",
    description: "A luxury cabinet for testing"
  }
} as const;

export const TEST_GACHA_PRICES = {
  CHEAP_PLAY: parseEther("0.01"),
  MEDIUM_PLAY: parseEther("0.05"),
  EXPENSIVE_PLAY: parseEther("0.1")
} as const;

export const TEST_MARKETPLACE_LISTINGS = {
  BASIC_LISTING: {
    price: parseEther("0.2"),
    isActive: true
  },

  PREMIUM_LISTING: {
    price: parseEther("0.8"),
    isActive: true
  },

  LUXURY_LISTING: {
    price: parseEther("1.5"),
    isActive: true
  }
} as const;

export const TEST_TUUCOIN_CONFIG = {
  EMISSION_RATE: 10n, // 10 TuuCoins per failed gacha
  BURN_AMOUNT: 50n,   // 50 TuuCoins to improve odds
  ODDS_IMPROVEMENT: 500n, // 5% odds improvement (500 basis points)
  MAX_SUPPLY: parseUnits("1000000", 18) // 1M TuuCoins max supply
} as const;

export const TEST_FEE_CONFIG = {
  PLATFORM_FEE_RATE: 250n, // 2.5% (250 basis points)
  MARKETPLACE_FEE_RATE: 500n // 5% (500 basis points)
} as const;

export const TEST_ACCESS_ROLES = {
  ADMIN_ROLE: "0x0000000000000000000000000000000000000000000000000000000000000000",
  MINTER_ROLE: "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
  PAUSER_ROLE: "0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a",
  EMERGENCY_RESPONDER_ROLE: "0x7935bd0ae54bc31f548c14dba4d37c5c64b3f8ca900cb468fb8abd54d5894f55"
} as const;

export const TEST_MOCK_NFTS = [
  {
    tokenId: 1n,
    name: "Test NFT 1",
    rarity: "common"
  },
  {
    tokenId: 2n,
    name: "Test NFT 2",
    rarity: "rare"
  },
  {
    tokenId: 3n,
    name: "Test NFT 3",
    rarity: "epic"
  },
  {
    tokenId: 4n,
    name: "Test NFT 4",
    rarity: "legendary"
  }
] as const;

export const TEST_SCENARIOS = {
  SUCCESSFUL_GACHA_PLAY: {
    description: "Player wins a prize from gacha",
    expectedOutcome: "NFT transferred to player"
  },

  FAILED_GACHA_PLAY: {
    description: "Player fails gacha and receives TuuCoins",
    expectedOutcome: "TuuCoins minted to player"
  },

  CABINET_PURCHASE: {
    description: "User purchases cabinet from tier sale",
    expectedOutcome: "Cabinet NFT minted to user"
  },

  MARKETPLACE_TRANSACTION: {
    description: "User buys cabinet from marketplace",
    expectedOutcome: "Cabinet transferred, payment distributed"
  },

  CABINET_CONFIGURATION: {
    description: "Owner configures cabinet settings",
    expectedOutcome: "Cabinet settings updated successfully"
  },

  REVENUE_WITHDRAWAL: {
    description: "Cabinet owner withdraws accumulated revenue",
    expectedOutcome: "Revenue transferred to owner"
  }
} as const;