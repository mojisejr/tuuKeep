---
## Project Overview

**TuuKeep** - Decentralized Gachapon Platform built on blockchain. Users own **Gachapon Cabinet NFTs** as income-generating assets. Cabinet owners fill machines with assets and collect fees from players.

### Development Guidelines

**⚠️ CRITICAL: Time Sync Required**
```bash
date +"%Y-%m-%d %H:%M:%S"  # Run before file operations
```

**File Naming**: `session-YYYY-MM-DD-[description].md`, Thailand timezone, Christian Era dates.

---

## Architecture Overview

**Tech Stack**:
- Next.js 14 + React 18 + TypeScript + Tailwind CSS
- shadcn/ui components, Framer Motion, wagmi/viem
- Hardhat 3.0 + Solidity 0.8.28 (nested monorepo)
- Bitkub Chain (KUB) + Ethereum networks

**Smart Contracts**:
- **TuuKeepCabinet.sol**: Cabinet management, gameplay
- **TuuCoin.sol**: Platform token, odds modification
- **TuuKeepMarketplace.sol**: P2P trading
- **Utils/Randomness.sol**: On-chain randomness

**Page Structure**:
- `/`: Browse available cabinets
- `/cabinet/[id]`: Play gacha with TuuCoin odds
- `/my-cabinets`: Owner dashboard
- `/marketplace`: Secondary market
- `/mint-cabinet`: Admin interface

**Bitkub Chain Networks**:
- KUB Testnet: Chain 25925, https://rpc-testnet.bitkubchain.io
- KUB Mainnet: Chain 96, https://rpc.bitkubchain.io

**Monorepo Structure**:
- Root: Next.js app (`/src/app/`, `/src/components/`)
- `/contracts/`: Isolated Hardhat project

---

## ⚠️ CRITICAL SAFETY RULES

- **NEVER merge PRs**: Only provide PR link, wait for user approval
- **NO critical file deletion**: `.env`, `.git/`, `node_modules/`, etc.
- **Protect sensitive data**: Use env vars, never commit secrets
- **Stay in scope**: Focus only on assigned tasks
- **Contract safety**: Test thoroughly on testnet first

**Key Environment Variables**: Private keys, RPC URLs, contract addresses for testnet/mainnet deployment and frontend integration.

---

## 🚀 Development Workflows

### The Two-Issue Pattern

This project uses a Two-Issue Pattern to separate work context from actionable plans, integrating local workflows with GitHub Issues for clarity and traceability.

- **Context Issues (`=fcs`):** Used to record the current state and context of a session on GitHub.

- **Task Issues (`=plan`):** Used to create a detailed and comprehensive plan of action on GitHub. The agent will use information from the latest Context Issue as a reference.

---

### Shortcut Commands

These commands are standard across all projects and streamline our communication with **AUTOMATED WORKFLOW INTEGRATION**.

- **`=fcs > [message]`**: Updates the `current-focus.md` file on the local machine and creates a **GitHub Context Issue** with the specified `[message]` as the title. **WARNING**: This command will only work if there are no open GitHub issues. If there are, the agent will alert you to clear the backlog before you can save a new context. To bypass this check, use the command `=fcs -f > [message]`.

- **`=plan > [question/problem]`**: Creates a **GitHub Task Issue** with a detailed and comprehensive plan of action. **ENHANCED WITH CODEBASE ANALYSIS** - The agent will:

  1. **Codebase Analysis Phase**: For non-new feature implementations (fixes, refactors, modifications):

     - Search and analyze all relevant code components and dependencies
     - Identify side effects and interconnected systems
     - Review existing patterns, conventions, and architectural decisions
     - Map data flow and component relationships
     - Assess impact on related functionality

  2. **Plan Creation Phase**: Use all gathered information including:
     - Current focus context from `current-focus.md`
     - Previous conversation history
     - Comprehensive codebase analysis results
     - Identified dependencies and side effects

  If an open Task Issue already exists, the agent will **update** that Issue with the latest information instead of creating a new one.

- **`=impl > [message]`**: **ENHANCED WITH AUTOMATED WORKFLOW** - Instructs the agent to execute the plan contained in the latest **GitHub Task Issue** with full automation:

  1. **Auto-Branch Creation**: Creates feature branch with proper naming (`feature/[issue-number]-[description]`)
  2. **Implementation**: Executes the planned work
  3. **Auto-Commit & Push**: Commits changes with descriptive messages and pushes to remote
  4. **Auto-PR Creation**: Creates Pull Request with proper description and issue references
  5. **Issue Updates**: Updates the plan issue with PR link and completion status
  6. **User Notification**: Provides PR link for review and approval

- **`=rrr > [message]`**: Creates a daily Retrospective file in the `docs/retrospective/` folder and creates a GitHub Issue containing a summary of the work, an AI Diary, and Honest Feedback, allowing you and the team to review the session accurately.

### 🔄 Plan Issue Management Guidelines

**CRITICAL**: For large, multi-phase projects, the agent must **UPDATE** existing plan issues instead of creating new ones.

- **When completing phases**: Update the plan issue to reflect completed phases and mark them as ✅ COMPLETED
- **Progress tracking**: Update the issue description with current status, next steps, and any blockers
- **Phase completion**: When a phase is finished, update the plan issue immediately before moving to the next phase
- **Never create new issues**: For ongoing multi-phase work, always update the existing plan issue (#20 for current system refactor)
- **Retrospective issues**: Only create retrospective issues for session summaries, not for plan updates

### 🎯 Enhanced Implementation Workflows

#### Multi-Phase Implementation Strategy

**Proven 5-Phase Approach** (15-34 minute sessions):

1. **Analysis & Preparation** (5-8 min): Component analysis, dependency mapping
2. **Core Implementation** (8-15 min): Primary changes, API updates
3. **Integration & Testing** (3-8 min): Build validation, error resolution
4. **Documentation & PR** (2-5 min): Commits, pull requests
5. **Cleanup & Review** (1-2 min): Final validation

#### Reference Pattern Implementation

- **56% efficiency improvement** when following proven patterns
- Use `/docs/retrospective/` files as implementation guides
- Adapt existing solutions rather than creating from scratch

#### Branch Management Excellence

- **ALWAYS** create feature branches: `feature/[issue-number]-[description]`
- **NEVER** work directly on main branch
- **Workflow**: Analysis → Branch → Implementation → Build → Commit → PR → Updates

#### TodoWrite Integration Patterns

**High-Impact Usage**: Complex refactoring (3+ files), multi-phase implementations, large system changes
**Best Practices**: 5-8 specific todos, exactly ONE in_progress, complete immediately after finishing

### 🌿 Automated Workflow Implementation

**ENHANCED AUTOMATION**: All development workflows now include full automation to ensure consistent adherence to project guidelines.

#### Enhanced Command Behavior

The following commands now include **FULL WORKFLOW AUTOMATION**:

##### `=impl` Command Enhancement

**Automated Execution Flow:**

```
1. Parse GitHub Task Issue → Extract requirements and scope
2. Auto-Branch Creation → feature/[issue-number]-[sanitized-description]
3. Implementation Phase → Execute planned work with progress tracking
4. Auto-Commit & Push → Descriptive commits with proper formatting
5. Auto-PR Creation → Comprehensive PR with issue linking
6. Issue Updates → Update plan issue with PR link and completion status
7. User Notification → Provide PR URL for review and approval
```

##### TodoWrite Integration Enhancement

**Performance Impact from Retrospectives**: 56% faster implementations when TodoWrite is integrated

**Enhanced Implementation Flow with TodoWrite:**

```
1. Parse GitHub Task Issue → Extract requirements and scope
2. Initialize TodoWrite → Create 5-8 specific, actionable todos
3. Auto-Branch Creation → feature/[issue-number]-[sanitized-description]
4. Implementation Phase → Execute with real-time todo tracking
   ├─ Mark exactly ONE todo as 'in_progress' at a time
   ├─ Complete todos immediately after finishing each step
   ├─ Update progress visibility for stakeholders
   └─ Ensure accountability for all implementation steps
5. Auto-Commit & Push → Descriptive commits with proper formatting
6. Auto-PR Creation → Comprehensive PR with issue linking
7. Issue Updates → Update plan issue with PR link and completion status
8. TodoWrite Completion → Mark all todos as completed
9. User Notification → Provide PR URL for review and approval
```

**TodoWrite Performance Benefits:**

- **Visibility**: Real-time progress tracking for stakeholders
- **Accountability**: Prevents skipping critical implementation steps
- **Focus**: Reduces context switching during complex implementations
- **Efficiency**: Proven 15-minute implementations vs 34-minute baseline
- **Documentation**: Creates audit trail of implementation progress

**High-Impact TodoWrite Usage Patterns:**

```markdown
✅ Complex multi-component refactoring (3+ files)
✅ Full-stack implementations (API + Frontend)
✅ Multi-phase system changes (Database + Application)
✅ Pattern replication following proven approaches
✅ Large refactoring with dependency management

❌ Single file edits or trivial changes
❌ Simple documentation updates
❌ Quick bug fixes without multiple steps
```

##### Branch Naming Convention

- **Format**: `feature/[issue-number]-[sanitized-description]`
- **Example**: `feature/27-deployment-production-implementation`
- **Auto-sanitization**: Removes special characters, converts to kebab-case

##### Commit Message Standards

- **Format**: `[type]: [description] (#[issue-number])`
- **Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
- **Example**: `feat: implement user authentication system (#25)`

##### Pull Request Automation

- **Title**: Auto-generated from issue title with proper formatting
- **Description**: Includes implementation summary, changes made, and testing notes
- **Issue Linking**: Automatic `Closes #[issue-number]` for proper tracking
- **Labels**: Auto-applied based on implementation type and scope

#### Workflow Safety Measures

- **Branch Protection**: Prevents direct commits to main/master
- **PR Validation**: Ensures all changes go through review process
- **Issue Tracking**: Maintains complete audit trail of work
- **Status Updates**: Real-time progress tracking and notifications

**CRITICAL**: **NEVER** work directly on main/master branch. **ALWAYS** create PRs for review.

### Implementation Guidelines for Automated Workflow

#### Pre-Implementation Checks

- ✅ Verify GitHub Task Issue exists and is properly formatted
- ✅ Ensure no conflicting branches exist
- ✅ Confirm GitHub CLI is authenticated and functional
- ✅ Validate repository permissions for branch creation and PR management

#### Error Handling and Fallbacks

- **Branch Creation Failure**: Falls back to manual branch creation with user guidance
- **Push Failure**: Provides manual push commands and troubleshooting steps
- **PR Creation Failure**: Falls back to manual PR creation with pre-filled templates
- **Issue Update Failure**: Logs error and provides manual update instructions

#### Quality Assurance

- **Code Review**: All PRs require manual review and approval
- **Testing**: Automated tests run on PR creation (if configured)
- **Documentation**: Auto-generated PR descriptions include implementation details
- **Rollback**: Clear instructions for reverting changes if needed

#### Monitoring and Feedback

- **Progress Tracking**: Real-time updates during implementation phases
- **Success Metrics**: PR creation success rate and review completion time
- **User Feedback**: Continuous improvement based on workflow effectiveness
- **Audit Trail**: Complete history of automated actions for debugging

---

## 🛡️ Security & Performance Guidelines

### Security Implementation (8-Phase, 31-min process)
1. Infrastructure + Endpoint Analysis (input validation, rate limiting)
2. Data Integrity + Compliance (PCI DSS, GDPR)
3. Vulnerability Testing + Implementation
4. Build Validation + Documentation

**Key Practices**: Rate limiting, Zod schemas, generic error responses, webhook signature validation

### Performance Optimization (15-min vs 34-min baseline)
**High Efficiency Factors**:
- TodoWrite usage for progress tracking
- Reference pattern from `/docs/retrospective/`
- Systematic 5-phase approach
- Proactive build validation (`npm run build`, `npx tsc --noEmit`)

**Performance Metrics**: 56% faster with pattern replication, 100% build success target

### UI/UX Standards
- WCAG 2.1 AA compliance (4.5:1 contrast)
- Centralized styling utilities (`src/utils/campaignStyles.ts`)
- 60fps animations, responsive design
- Reduced motion support

---

## 🛠️ Development Commands

### Core Development

```bash
# Development server
npm run dev

# Build for production
npm run build

# Start production server
npm start

# Type checking
npm run lint
```

### Smart Contract Development

```bash
# Navigate to contracts folder
cd contracts

# Install Hardhat dependencies
npm install

# Compile contracts with Solidity 0.8.28
npx hardhat compile

# Run all tests (Solidity + Node.js)
npx hardhat test

# Run specific test types
npx hardhat test solidity    # Foundry-compatible tests
npx hardhat test nodejs      # TypeScript integration tests

# Deploy to local simulated network
npx hardhat ignition deploy ignition/modules/Counter.ts

# Deploy to Sepolia testnet (requires SEPOLIA_PRIVATE_KEY)
npx hardhat keystore set SEPOLIA_PRIVATE_KEY  # Set private key securely
npx hardhat ignition deploy --network sepolia ignition/modules/Counter.ts

# Test OP chain simulation
npx hardhat run scripts/send-op-tx.ts --network hardhatOp
```

### Hardhat Configuration Details

**Solidity Profiles**:
- **Default**: Version 0.8.28 for development
- **Production**: Version 0.8.28 with optimizer (200 runs)

**Network Configuration**:
- **hardhatMainnet**: EDR simulated L1 chain
- **hardhatOp**: EDR simulated Optimism chain
- **sepolia**: HTTP connection with configurable RPC URL and private key (Chain ID: 11155111)
- **kubTestnet**: KUB Testnet connection (Chain ID: 25925, RPC: https://rpc-testnet.bitkubchain.io)
- **kubMainnet**: KUB Mainnet connection (Chain ID: 96, RPC: https://rpc.bitkubchain.io)

**Key Features**:
- **Hardhat 3.0 Beta**: Latest features with viem integration
- **TypeScript Support**: Full TypeScript integration for scripts and tests
- **Configuration Variables**: Secure handling of sensitive data (RPC URLs, private keys)
- **Multi-chain Support**: L1 and L2 (Optimism) simulation capabilities
- **Ignition Deployment**: Modern deployment system with state management

### Web3 Integration

```bash
# Generate contract types for viem (Hardhat 3.0 handles this automatically)
# Types are generated during compilation with @nomicfoundation/hardhat-toolbox-viem

# Verify contracts on Etherscan
npx hardhat verify --network sepolia DEPLOYED_CONTRACT_ADDRESS
npx hardhat verify --network mainnet DEPLOYED_CONTRACT_ADDRESS

# Verify contracts on KubScan (Bitkub Chain)
npx hardhat verify --network kubTestnet DEPLOYED_CONTRACT_ADDRESS
npx hardhat verify --network kubMainnet DEPLOYED_CONTRACT_ADDRESS

# Check contract deployment status
npx hardhat ignition status ignition/deployments/chain-[CHAIN_ID]/

# Interact with deployed contracts using viem
node -e "import('./scripts/interact.js')"
```

---

## 📚 Best Practices

### TodoWrite Integration (56% faster implementations)
**Use for**: Complex multi-step tasks, security audits, large refactoring
**Pattern**: 5-12 todos, exactly ONE in_progress, real-time visibility

### Pattern Replication Strategy
1. Document successful patterns in `/docs/retrospective/`
2. Use previous sessions as implementation guides
3. Adapt proven patterns for new contexts
4. Measure efficiency improvements

### Build Validation Checkpoints
- **Schema Changes**: `npm run build && npx tsc --noEmit`
- **Incremental Testing**: Build after each major change
- **Database Sync**: `npx prisma generate` after schema changes

### Smart Contract Security
- Access control, reentrancy protection, gas optimization
- Unit + integration tests, edge case testing
- Test on local/testnet before mainnet

### Multi-Phase Implementation (4-phase approach)
1. Analysis & Preparation (10-15%)
2. Core Implementation (40-50%)
3. Integration & Testing (25-30%)
4. Documentation & Cleanup (10-15%)

---

## 🔧 Troubleshooting

### Build Issues
```bash
npm run build 2>&1 | grep -A 5 "error"  # Check errors
rm -rf node_modules .next .cache && npm install  # Reset
npx prisma generate  # Reset Prisma
```

### Smart Contract Issues
- **Deployment**: Test locally first (`npx hardhat node`)
- **ABI Sync**: Regenerate types after redeployment
- **Network Config**: Verify Hardhat configuration
- **Gas Issues**: Check gas prices, use ETH Gas Station

### Web3 Integration
- Verify contract addresses match frontend config
- Regenerate contract types: `npx typechain`
- Test incremental changes with build validation
- Check wallet connection and network selection

### Common Fixes
- **Port conflicts**: `lsof -i :3000` then `kill -9 [PID]`
- **Schema issues**: Always verify Prisma schema, never assume field names
- **Security**: Use Zod validation, generic error responses
- **Performance**: Monitor Core Web Vitals, gas usage, transaction times
