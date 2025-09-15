import type { HardhatUserConfig } from "hardhat/config";

import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import { configVariable } from "hardhat/config";

const config: HardhatUserConfig = {
  plugins: [hardhatToolboxViemPlugin],
  solidity: {
    profiles: {
      default: {
        version: "0.8.28",
      },
      production: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },
  networks: {
    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1",
    },
    hardhatOp: {
      type: "edr-simulated",
      chainType: "op",
    },
    sepolia: {
      type: "http",
      chainType: "l1",
      url: configVariable("SEPOLIA_RPC_URL"),
      accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
    },
    kubTestnet: {
      type: "http",
      chainType: "l1",
      url: process.env.KUB_TESTNET_RPC_URL || "https://rpc-testnet.bitkubchain.io",
      accounts: process.env.KUB_TESTNET_PRIVATE_KEY ? [process.env.KUB_TESTNET_PRIVATE_KEY] : [],
      chainId: 25925,
    },
    kubMainnet: {
      type: "http",
      chainType: "l1",
      url: process.env.KUB_MAINNET_RPC_URL || "https://rpc.bitkubchain.io",
      accounts: process.env.KUB_MAINNET_PRIVATE_KEY ? [process.env.KUB_MAINNET_PRIVATE_KEY] : [],
      chainId: 96,
    },
  },
};

export default config;
