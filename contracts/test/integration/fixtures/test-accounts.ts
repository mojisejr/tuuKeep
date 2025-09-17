import { parseEther } from "viem";

export interface TestAccount {
  address: `0x${string}`;
  role: string;
  initialBalance: bigint;
}

export const TEST_ACCOUNTS = {
  // Platform Admin - manages all contracts
  PLATFORM_ADMIN: {
    address: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" as `0x${string}`,
    role: "PLATFORM_ADMIN",
    initialBalance: parseEther("1000")
  },

  // Cabinet Owner - owns and manages cabinets
  CABINET_OWNER: {
    address: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC" as `0x${string}`,
    role: "CABINET_OWNER",
    initialBalance: parseEther("500")
  },

  // Cabinet Owner 2 - secondary owner for multi-owner tests
  CABINET_OWNER_2: {
    address: "0x90F79bf6EB2c4f870365E785982E1f101E93b906" as `0x${string}`,
    role: "CABINET_OWNER_2",
    initialBalance: parseEther("500")
  },

  // Player accounts for gacha testing
  PLAYER_1: {
    address: "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65" as `0x${string}`,
    role: "PLAYER_1",
    initialBalance: parseEther("100")
  },

  PLAYER_2: {
    address: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc" as `0x${string}`,
    role: "PLAYER_2",
    initialBalance: parseEther("100")
  },

  PLAYER_3: {
    address: "0x976EA74026E726554dB657fA54763abd0C3a0aa9" as `0x${string}`,
    role: "PLAYER_3",
    initialBalance: parseEther("100")
  },

  // Marketplace participants
  MARKETPLACE_BUYER: {
    address: "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955" as `0x${string}`,
    role: "MARKETPLACE_BUYER",
    initialBalance: parseEther("200")
  },

  MARKETPLACE_SELLER: {
    address: "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f" as `0x${string}`,
    role: "MARKETPLACE_SELLER",
    initialBalance: parseEther("200")
  },

  // Fee recipients
  FEE_RECIPIENT: {
    address: "0xa0Ee7A142d267C1f36714E4a8F75612F20a79720" as `0x${string}`,
    role: "FEE_RECIPIENT",
    initialBalance: parseEther("0")
  },

  // Emergency responder
  EMERGENCY_RESPONDER: {
    address: "0xBcd4042DE499D14e55001CcbB24a551F3b954096" as `0x${string}`,
    role: "EMERGENCY_RESPONDER",
    initialBalance: parseEther("10")
  }
} as const;

export const getAllTestAccounts = (): TestAccount[] => {
  return Object.values(TEST_ACCOUNTS);
};

export const getAccountsByRole = (role: string): TestAccount[] => {
  return getAllTestAccounts().filter(account => account.role === role);
};