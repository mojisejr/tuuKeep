# TuuKeep Deployment Infrastructure

Complete deployment infrastructure for the TuuKeep ecosystem using Hardhat Ignition.

## 🏗️ Architecture Overview

The TuuKeep ecosystem consists of 6 core contracts deployed in dependency order:

1. **TuuKeepAccessControl** - Role-based access control foundation
2. **TuuCoin** - Platform token with cabinet integration
3. **Randomness** - Secure randomness utility for gacha mechanics
4. **TuuKeepCabinet** - Core NFT contract with gacha gameplay
5. **TuuKeepMarketplace** - P2P trading system
6. **TuuKeepTierSale** - Tier-based initial sales

## 📁 Directory Structure

```
contracts/
├── ignition/modules/          # Hardhat Ignition deployment modules
│   ├── TuuKeepAccessControl.ts
│   ├── TuuCoin.ts
│   ├── Randomness.ts
│   ├── TuuKeepCabinet.ts
│   ├── TuuKeepMarketplace.ts
│   ├── TuuKeepTierSale.ts
│   └── FullEcosystem.ts       # Complete ecosystem orchestrator
├── scripts/                   # Deployment and validation scripts
│   ├── deploy-ecosystem.ts    # Comprehensive deployment script
│   ├── verify-ecosystem.ts    # Contract verification on KubScan
│   └── validate-deployment.ts # Post-deployment validation
└── deployments/               # Deployment results (auto-generated)
    ├── kubTestnet-latest.json
    ├── kubMainnet-latest.json
    ├── kubTestnet.env
    └── kubMainnet.env
```

## 🚀 Quick Start

### Prerequisites

1. **Node.js 22.10.0+** (required for Hardhat 3.0)
2. **Environment Variables** configured
3. **KUB/ETH balance** for deployment gas fees

### Environment Setup

Create `.env` file with required variables:

```bash
# Admin Configuration
DEFAULT_ADMIN=0x...              # Address that receives admin roles
PLATFORM_TREASURY=0x...         # Revenue collection address
PLATFORM_FEE_RECIPIENT=0x...    # Fee collection address

# Network Configuration
KUB_TESTNET_RPC_URL=https://rpc-testnet.bitkubchain.io
KUB_TESTNET_PRIVATE_KEY=0x...
KUB_MAINNET_RPC_URL=https://rpc.bitkubchain.io
KUB_MAINNET_PRIVATE_KEY=0x...

# Optional: Contract Verification
KUBSCAN_API_KEY=your-api-key     # For automatic verification
```

### One-Click Deployment

Deploy the complete ecosystem:

```bash
# KUB Testnet
npm run deploy:testnet

# KUB Mainnet
npm run deploy:mainnet
```

### Manual Deployment

Step-by-step deployment using Hardhat Ignition:

```bash
# 1. Deploy complete ecosystem
npx hardhat ignition deploy ignition/modules/FullEcosystem.ts \
  --network kubTestnet \
  --parameters '{
    "defaultAdmin":"0x...",
    "platformTreasury":"0x...",
    "platformFeeRecipient":"0x..."
  }'

# 2. Verify contracts
npx hardhat run scripts/verify-ecosystem.ts --network kubTestnet

# 3. Validate deployment
npx hardhat run scripts/validate-deployment.ts --network kubTestnet
```

## 🔧 Individual Contract Deployment

Deploy contracts individually for testing or partial deployments:

### 1. TuuKeepAccessControl (Foundation)

```bash
npx hardhat ignition deploy ignition/modules/TuuKeepAccessControl.ts \
  --network kubTestnet \
  --parameters '{"defaultAdmin":"0x..."}'
```

### 2. TuuCoin (Token Economy)

```bash
npx hardhat ignition deploy ignition/modules/TuuCoin.ts \
  --network kubTestnet \
  --parameters '{
    "accessControl":"0x...",
    "initialAdmin":"0x..."
  }'
```

### 3. Randomness (Utility)

```bash
npx hardhat ignition deploy ignition/modules/Randomness.ts \
  --network kubTestnet \
  --parameters '{"admin":"0x..."}'
```

### 4. TuuKeepCabinet (Core NFT)

```bash
npx hardhat ignition deploy ignition/modules/TuuKeepCabinet.ts \
  --network kubTestnet \
  --parameters '{
    "accessControl":"0x...",
    "tuuCoin":"0x...",
    "randomness":"0x...",
    "platformFeeRecipient":"0x..."
  }'
```

### 5. TuuKeepMarketplace (P2P Trading)

```bash
npx hardhat ignition deploy ignition/modules/TuuKeepMarketplace.ts \
  --network kubTestnet \
  --parameters '{
    "cabinetContract":"0x...",
    "accessControl":"0x...",
    "platformFeeRecipient":"0x..."
  }'
```

### 6. TuuKeepTierSale (Initial Sales)

```bash
npx hardhat ignition deploy ignition/modules/TuuKeepTierSale.ts \
  --network kubTestnet \
  --parameters '{
    "cabinetContract":"0x...",
    "platformTreasury":"0x...",
    "admin":"0x..."
  }'
```

## 🔍 Verification

### Automatic Verification

```bash
npx hardhat run scripts/verify-ecosystem.ts --network kubTestnet
```

### Manual Verification

Individual contract verification:

```bash
npx hardhat verify --network kubTestnet CONTRACT_ADDRESS "CONSTRUCTOR_ARG1" "CONSTRUCTOR_ARG2"
```

## ✅ Post-Deployment Validation

Validate the deployed ecosystem:

```bash
npx hardhat run scripts/validate-deployment.ts --network kubTestnet
```

The validation script checks:
- ✅ Contract deployment status
- ✅ Access control integration
- ✅ Cross-contract dependencies
- ✅ Basic functionality

## 📊 Gas Optimization

All contracts are optimized for KUB network deployment:

- **TuuKeepCabinet**: 24,450 bytes (within 24,576 limit)
- **Deployment costs**: 8-12M gas per contract
- **Function calls**: <200k gas for high-frequency operations
- **Gas reporting**: Enabled with `REPORT_GAS=true`

## 🔐 Security Features

### Access Control
- Role-based permissions across all contracts
- Emergency pause capabilities
- Multi-signature admin support

### Validation
- Constructor parameter validation
- Cross-contract dependency verification
- Post-deployment integration testing

### Best Practices
- Reentrancy protection
- Gas optimization
- Event emission standards

## 🌐 Network Configuration

### KUB Testnet
- **Chain ID**: 25925
- **RPC**: https://rpc-testnet.bitkubchain.io
- **Explorer**: https://testnet.kubscan.io
- **Gas**: Auto-configured with 1.2x multiplier

### KUB Mainnet
- **Chain ID**: 96
- **RPC**: https://rpc.bitkubchain.io
- **Explorer**: https://kubscan.io
- **Gas**: Auto-configured with 1.1x multiplier

## 🔄 Integration Workflow

Post-deployment integration setup:

1. **Register Cabinet as Randomness Consumer**
   ```bash
   # Grant CONSUMER_ROLE to cabinet contract
   randomness.addConsumer(cabinetAddress)
   ```

2. **Grant Cabinet Operator Role in TuuCoin**
   ```bash
   # Allow cabinet to mint/burn TuuCoins
   tuuCoin.grantRole(CABINET_OPERATOR_ROLE, cabinetAddress)
   ```

3. **Grant Minter Role to TierSale**
   ```bash
   # Allow tier sale to mint cabinets
   cabinet.grantRole(MINTER_ROLE, tierSaleAddress)
   ```

4. **Configure Platform Settings**
   - Set platform fee rates
   - Configure emission parameters
   - Set up tier sale phases

## 📱 Frontend Integration

After deployment, update frontend configuration:

```typescript
// Update contract addresses in frontend
export const CONTRACT_ADDRESSES = {
  CABINET: "0x...",
  TUUCOIN: "0x...",
  MARKETPLACE: "0x...",
  TIER_SALE: "0x...",
  ACCESS_CONTROL: "0x...",
  RANDOMNESS: "0x..."
} as const;
```

## 🚨 Troubleshooting

### Common Issues

1. **Node.js Version Error**
   ```bash
   nvm use v22
   cd contracts && rm -rf node_modules && npm install
   ```

2. **Gas Estimation Failed**
   - Check account balance
   - Verify network configuration
   - Increase gas multiplier

3. **Verification Failed**
   - Wait for block confirmations
   - Check constructor arguments
   - Verify API key configuration

### Support

- **Documentation**: `/docs/` directory
- **Examples**: Individual module files
- **Testing**: `npm test` for validation

## 📝 Deployment Checklist

- [ ] Environment variables configured
- [ ] Node.js 22.10.0+ installed
- [ ] Account has sufficient balance
- [ ] Network configuration verified
- [ ] Deployment parameters validated
- [ ] Contracts compiled successfully
- [ ] Deployment executed
- [ ] Contracts verified on KubScan
- [ ] Post-deployment validation passed
- [ ] Frontend addresses updated
- [ ] Integration workflow completed

---

🎉 **Ready for Production!** The TuuKeep ecosystem is now deployed and validated on KUB network.