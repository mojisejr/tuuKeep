import type { HardhatUserConfig } from "hardhat/config";

import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import { configVariable } from "hardhat/config";

const config: HardhatUserConfig = {
  plugins: [hardhatToolboxViemPlugin],
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
      evmVersion: "london", // Use London instead of Shanghai to avoid PUSH0 opcode
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
      gasPrice: "auto",
      gas: "auto",
      gasMultiplier: 1.2,
      timeout: 60000,
    },
    kubMainnet: {
      type: "http",
      chainType: "l1",
      url: process.env.KUB_MAINNET_RPC_URL || "https://rpc.bitkubchain.io",
      accounts: (process.env.KUB_MAINNET_PRIVATE_KEY && process.env.KUB_MAINNET_PRIVATE_KEY !== "your_kub_mainnet_private_key_here") ? [process.env.KUB_MAINNET_PRIVATE_KEY] : [],
      chainId: 96,
      gasPrice: "auto",
      gas: "auto",
      gasMultiplier: 1.1,
      timeout: 120000,
    },
  },
  etherscan: {
    apiKey: {
      kubTestnet: process.env.KUBSCAN_API_KEY || "dummy-key",
      kubMainnet: process.env.KUBSCAN_API_KEY || "dummy-key",
    },
    customChains: [
      {
        network: "kubTestnet",
        chainId: 25925,
        urls: {
          apiURL: "https://testnet.kubscan.io/api",
          browserURL: "https://testnet.kubscan.io",
        },
      },
      {
        network: "kubMainnet",
        chainId: 96,
        urls: {
          apiURL: "https://kubscan.io/api",
          browserURL: "https://kubscan.io",
        },
      },
    ],
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true",
    currency: "USD",
    gasPrice: 20,
    showTimeSpent: true,
    showMethodSig: true,
  },
  mocha: {
    timeout: 60000,
  },
};

export default config;
