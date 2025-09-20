---
## Project Overview

**Project Name**: TuuKeep - Decentralized Gachapon Platform

**Repository**: https://github.com/mojisejr/tuuKeep

**Description**: Blockchain-based gachapon platform where users own **Gachapon Cabinet NFTs** as income-generating assets. Cabinet owners fill machines with digital assets and collect fees from players. Built on Bitkub Chain (KUB) with multi-entropy randomness and comprehensive smart contract architecture.

**Project Goals**:

- Create decentralized ownership model for gachapon cabinets as NFT assets
- Provide sustainable income streams for cabinet owners through gameplay fees
- Ensure fair and transparent randomness using multi-entropy on-chain systems
- Build comprehensive marketplace for cabinet trading and asset management
- Maintain enterprise-grade security and gas optimization

---

### Development Guidelines

**⚠️ CRITICAL: Synchronize Time Before Any File Operations**

Before creating a new file or saving any timestamps, you **MUST** use the following command to retrieve the current date and time from the system:

```bash
date +"%Y-%m-%d %H:%M:%S"
```

This ensures accurate timestamp synchronization with the system clock and prevents time-related inconsistencies.

#### File Naming Conventions

- **Retrospective Files**: `session-YYYY-MM-DD-[description].md`
- **Log Files**: `YYYY-MM-DD-[type].log`
- **Backup Files**: `backup-YYYY-MM-DD-HHMM.sql`

#### Important Notes

- **ALL timestamps** in documentation, logs, and file names must use Thailand timezone
- **Year format** must always be Christian Era (ค.ศ.) not Buddhist Era (พ.ศ.)
- **Development sessions** should reference Thailand local time
- **Retrospective files** must use correct Thailand date in filename

---

## Architecture Overview

### Core Structure

- **Framework**: Next.js 14 (App Router)
- **Frontend/Framework**: React 18 with TypeScript (Strict Mode)
- **Smart Contracts**: Hardhat 3.0 with Solidity 0.8.28 (London EVM)
- **Blockchain Integration**: wagmi/viem for Web3 connectivity
- **UI Components**: shadcn/ui with Tailwind CSS and Framer Motion
- **Networks**: Bitkub Chain (KUB) Testnet/Mainnet + Ethereum compatibility
- **Randomness**: Multi-entropy on-chain randomness system

### Tech Stack

- **Frontend**: Next.js 14, React 18, TypeScript, Tailwind CSS, Framer Motion, shadcn/ui
- **Web3 Integration**: wagmi, viem, @tanstack/react-query for blockchain connectivity
- **Smart Contracts**: Hardhat 3.0, Solidity 0.8.28, OpenZeppelin contracts
- **Blockchain**: Bitkub Chain (KUB) Testnet (25925) / Mainnet (96)
- **Development**: TypeScript, ESLint, Gas Reporter, Etherscan verification
- **Security**: Multi-layered access control, reentrancy guards, input validation

### Smart Contract Architecture

- **Core Contracts**:

  - `TuuKeepCabinet.sol`: Cabinet NFT management, gameplay mechanics, revenue tracking
  - `TuuCoin.sol`: Platform utility token for odds modification and rewards
  - `TuuKeepMarketplace.sol`: P2P trading platform for cabinet assets
  - `TuuKeepTierSale.sol`: Tiered sales system for cabinet distribution

- **Utility & Security**:

  - `Utils/Randomness.sol`: Multi-entropy randomness (block.prevrandao + timestamp + nonce)
  - `Utils/SVGGenerator.sol`: Dynamic NFT metadata and visual generation
  - `Utils/Security/`: Access control, reentrancy guards, validation libraries
  - `Utils/TuuKeepErrors.sol`: Centralized error handling and gas optimization

### Frontend Architecture

- **App Structure** (Next.js 14 App Router):
  - `/`: Browse available cabinets marketplace
  - `/cabinet/[id]`: Individual cabinet gameplay interface
  - `/my-cabinets`: Owner dashboard and management
  - `/marketplace`: Secondary market for cabinet trading
  - `/mint-cabinet`: Admin interface for cabinet creation

### Blockchain Networks

- **KUB Testnet**: Chain ID 25925, RPC: https://rpc-testnet.bitkubchain.io
- **KUB Mainnet**: Chain ID 96, RPC: https://rpc.bitkubchain.io
- **Development**: Local Hardhat networks (L1/L2 simulation)
- **Testing**: Sepolia testnet for cross-chain compatibility

### Monorepo Structure

- **Root**: Next.js application (`/src/app/`, `/src/components/`)
- **Contracts**: Isolated Hardhat project (`/contracts/`) with independent dependencies
- **Configuration**: Separate TypeScript configs for frontend and contracts

---

## ⚠️ CRITICAL SAFETY RULES

- **NEVER merge PRs**: Only provide PR link, wait for user approval
- **NO critical file deletion**: `.env`, `.git/`, `node_modules/`, etc.
- **Protect sensitive data**: Use env vars, never commit secrets
- **Stay in scope**: Focus only on assigned tasks
- **Contract safety**: Test thoroughly on testnet first

**Key Environment Variables**:
- `KUB_TESTNET_RPC_URL`, `KUB_MAINNET_RPC_URL`: Bitkub Chain RPC endpoints
- `KUB_TESTNET_PRIVATE_KEY`, `KUB_MAINNET_PRIVATE_KEY`: Deployment private keys
- `KUBSCAN_API_KEY`: Contract verification on KubScan explorer
- `NEXT_PUBLIC_CABINET_CONTRACT_ADDRESS`: Frontend contract integration
- `NEXT_PUBLIC_TUUCOIN_CONTRACT_ADDRESS`: TuuCoin token contract address

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

- **`=plan > [question/problem]`**: Creates a **GitHub Task Issue** with a detailed and comprehensive plan of action. **STAGING-FIRST WORKFLOW & CONFLICT PREVENTION** - The agent will:

  1. **Pre-Planning Validation**:

     - **Auto-check**: Verify staging branch is up-to-date with remote
     - **Warning**: Alert if staging is behind remote origin
     - **Mandatory Sync**: Automatically sync staging before planning if needed
     - **PR Status Check**: Verify no conflicting open PRs exist
     - **Branch Status**: Check for existing feature branches and potential conflicts

  2. **Codebase Analysis Phase**: For non-new feature implementations (fixes, refactors, modifications):

     - Search and analyze all relevant code components and dependencies
     - Identify side effects and interconnected systems
     - Review existing patterns, conventions, and architectural decisions
     - Map data flow and component relationships
     - Assess impact on related functionality
     - **File Coordination Check**: Identify high-risk files requiring team coordination

  3. **Plan Creation Phase**: Use all gathered information including:
     - Current focus context from `current-focus.md`
     - Previous conversation history
     - Comprehensive codebase analysis results
     - Identified dependencies and side effects
     - **Staging Context Creation**: Include `staging-context.md` creation in implementation plan

  If an open Task Issue already exists, the agent will **update** that Issue with the latest information instead of creating a new one.

- **`=impl > [message]`**: **STAGING-FIRST IMPLEMENTATION WORKFLOW** - Instructs the agent to execute the plan contained in the latest **GitHub Task Issue** with full automation:

  1. **Pre-Implementation Validation**:

     - **MANDATORY**: Ensure currently on staging branch (`git checkout staging`)
     - **MANDATORY**: Sync staging with remote origin (`git pull origin staging`)
     - **MANDATORY**: Verify no existing open PRs that could conflict
     - **MANDATORY**: Ensure clean working directory before proceeding
     - **Conflict Detection**: Check for potential conflicts before starting
     - **Emergency Protocol**: Activate emergency resolution if conflicts detected

  2. **Auto-Branch Creation**: Creates feature branch from staging with proper naming (`feature/[issue-number]-[description]`)
  3. **Implementation**: Executes the planned work with continuous conflict monitoring
  4. **Enhanced Commit & Push Flow**:

     - **Pre-commit Validation**: Check for conflicts before each commit
     - **Descriptive Commits**: Atomic commits with clear, descriptive messages
     - **Safe Push Strategy**: Force push only when necessary with `--force-with-lease`
     - **Conflict Resolution**: Automatic conflict detection and resolution protocols

  5. **Staging Context Creation**: Creates `staging-context.md` with implementation details
  6. **Auto-PR Creation**: Creates Pull Request **TO STAGING BRANCH ONLY** with proper description and issue references
  7. **Issue Updates**: Updates the plan issue with PR link and completion status
  8. **User Notification**: Provides PR link for review and approval - **USER HANDLES MAIN BRANCH MERGES MANUALLY**

- **`=stage > [message]`**: **STAGING DEPLOYMENT WORKFLOW** - Deploys approved changes from feature branch to staging environment:

  1. **Pre-Staging Validation**:

     - **Feature Branch Validation**: Ensure feature branch is ready for staging
     - **Conflict Resolution**: Resolve any conflicts with staging branch
     - **Test Validation**: Run automated tests before staging deployment

  2. **Staging Deployment**:

     - **Merge to Staging**: Merge approved feature branch to staging
     - **Staging Context Update**: Update `staging-context.md` with deployment details
     - **Auto-Deploy**: Trigger staging environment deployment
     - **Health Check**: Verify staging deployment health

  3. **Staging Validation**:

     - **Functional Testing**: Run staging environment tests
     - **Performance Monitoring**: Monitor staging performance metrics
     - **User Acceptance**: Prepare for user acceptance testing

  4. **Production Readiness**:
     - **Production Context**: Create production deployment context
     - **Rollback Plan**: Prepare rollback procedures
     - **Notification**: Alert team of staging deployment completion

- **`=prod > [message]`**: **PRODUCTION DEPLOYMENT WORKFLOW** - Deploys validated changes from staging to production:

  1. **Pre-Production Validation**:

     - **Staging Validation**: Ensure staging tests pass completely
     - **Security Review**: Complete security audit checklist
     - **Performance Baseline**: Establish performance benchmarks

  2. **Production Deployment**:

     - **Merge to Main**: Merge staging branch to main/production
     - **Production Deploy**: Execute production deployment pipeline
     - **Health Monitoring**: Monitor production health metrics
     - **Performance Tracking**: Track production performance

  3. **Post-Deployment**:

     - **Cleanup Operations**: Auto-cleanup `staging-context.md`
     - **Monitoring Setup**: Establish production monitoring
     - **Documentation**: Update production documentation
     - **Team Notification**: Notify team of successful production deployment

  4. **Rollback Readiness**:
     - **Rollback Procedures**: Maintain rollback capabilities
     - **Incident Response**: Prepare incident response protocols

- **`=rrr > [message]`**: Creates a daily Retrospective file in the `docs/retrospective/` folder and creates a GitHub Issue containing a summary of the work, an AI Diary, and Honest Feedback, allowing you and the team to review the session accurately.

### 📋 Staging Context File Management

#### Auto-Cleanup Strategy for `staging-context.md`

**File Creation & Location**:

- **Created during**: `=impl` command execution
- **Location**: Project root directory (`./staging-context.md`)
- **Content**: Implementation details, deployment context, testing notes

**Lifecycle Management**:

- **Creation**: Automatically generated during feature implementation
- **Updates**: Modified during `=stage` deployment process
- **Cleanup**: Automatically removed during `=prod` deployment completion
- **Backup**: Context preserved in PR descriptions and commit messages

**File Management Benefits**:

- **Deployment Tracking**: Clear visibility of staging deployment status
- **Context Preservation**: Implementation details available during staging phase
- **Automatic Cleanup**: No manual file management required
- **Conflict Prevention**: Reduces repository clutter and merge conflicts

**Cleanup Triggers**:

- **Successful Production Deployment**: File automatically deleted after `=prod` completion
- **Failed Deployments**: File retained for debugging and rollback procedures
- **Manual Cleanup**: Available via `=prod --cleanup-only` command
- **Branch Cleanup**: Removed when feature branch is deleted

### 🔄 Plan Issue Management Guidelines

**CRITICAL**: For large, multi-phase projects, the agent must **UPDATE** existing plan issues instead of creating new ones.

- **When completing phases**: Update the plan issue to reflect completed phases and mark them as ✅ COMPLETED
- **Progress tracking**: Update the issue description with current status, next steps, and any blockers
- **Phase completion**: When a phase is finished, update the plan issue immediately before moving to the next phase
- **Never create new issues**: For ongoing multi-phase work, always update the existing plan issue
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
✅ Full-stack implementations (Smart Contracts + Frontend)
✅ Multi-phase system changes (Blockchain + Application)
✅ Pattern replication following proven approaches
✅ Large refactoring with dependency management

❌ Single file edits or trivial changes
❌ Simple documentation updates
❌ Quick bug fixes without multiple steps
```

##### Branch Naming Convention

- **Format**: `feature/[issue-number]-[sanitized-description]`
- **Source**: All feature branches **MUST** be created from `staging` branch
- **Flow**: `feature/[issue] → staging → main`
- **Example**: `feature/27-cabinet-nft-marketplace-implementation`
- **Auto-sanitization**: Removes special characters, converts to kebab-case

##### Commit Message Standards

- **Format**: `[type]: [description] (#[issue-number])`
- **Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
- **Example**: `feat: implement cabinet NFT minting system (#25)`

##### Pull Request Automation

**Staging PRs** (Feature → Staging):

- **Title**: `[STAGING] [Feature Title] (#[issue-number])`
- **Description**: Implementation details, testing notes, staging deployment context
- **Context File**: References `staging-context.md` for deployment details
- **Issue Linking**: `Relates to #[issue-number]` (keeps issue open for production)

**Production PRs** (Staging → Main):

- **Title**: `[PRODUCTION] [Feature Title] (#[issue-number])`
- **Description**: Production deployment summary, staging validation results
- **Context File**: Includes staging validation and production readiness checklist
- **Issue Linking**: `Closes #[issue-number]` (closes issue after production deployment)

#### Workflow Safety Measures

**Enhanced Branch Protection**:

- **Main Branch**: Requires 2+ approvals, status checks, up-to-date branches
- **Staging Branch**: Requires 1+ approval, automated testing, conflict resolution
- **Feature Branches**: Standard protection, automated conflict detection

**Staging Sync Protocol**:

- **Pre-Implementation**: Always sync staging with main before creating feature branches
- **Pre-Staging**: Ensure feature branch is up-to-date with staging before PR
- **Pre-Production**: Validate staging branch is ready for main merge

**Conflict Prevention**:

- **Staging-First Rule**: All features go through staging before production
- **Sync Validation**: Automated checks for branch synchronization
- **Emergency Protocol**: Immediate conflict resolution for critical deployments

**CRITICAL RULES**:

- **NEVER** work directly on main/staging branches
- **ALWAYS** create feature branches from staging
- **ALWAYS** deploy to staging before production
- **ALWAYS** validate staging deployment before main PR

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

- ✅ **CRITICAL**: Verify Node.js version for contract work (`node --version` must be 22.10.0+)
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

## 📈 Retrospective Workflow

When you use the `=rrr` command, the agent will create a file and an Issue with the following sections and details:

### Retrospective Structure

**Required Sections**:

- **Session Details**: Date (YYYY-MM-DD Thailand timezone), Duration, Focus, Issue/PR references
- **Session Summary**: Overall work accomplished
- **Timeline**: Key events with Thailand timestamps (Asia/Bangkok, UTC+7)
- **📝 AI Diary** (MANDATORY): First-person reflection on approach and decisions
- **💭 Honest Feedback** (MANDATORY): Performance assessment and improvement suggestions
- **What Went Well**: Successes achieved
- **What Could Improve**: Areas for enhancement
- **Blockers & Resolutions**: Obstacles and solutions
- **Lessons Learned**: Patterns, mistakes, and discoveries

**File Naming**: `session-YYYY-MM-DD-[description].md` with Thailand date

---

## 📋 Best Practices from Retrospectives

_Lessons from TuuKeep development sessions in `/docs/retrospective/`_

### 🎯 TodoWrite Integration Best Practices

**Results**: **15-minute implementations** vs 34+ minute sessions

**When to Use**: Complex multi-step tasks (3+ phases), smart contract implementations, full-stack gachapon features, multi-component refactoring, security audits, marketplace development

**Workflow Pattern**:

1. Break into 5-12 manageable todos
2. Mark exactly ONE todo in_progress → completed
3. Provides real-time visibility and accountability
4. Enables accurate time estimation

**Proven Benefits**: 56% faster implementation, reduces context switching, prevents missing steps, ensures comprehensive testing

#### Advanced TodoWrite Patterns

- **Smart Contract Development**: 6-phase systematic approach

  - Phases 1-2: Contract Analysis & Security Review
  - Phases 3-4: Implementation & Gas Optimization
  - Phases 5-6: Testing & Deployment Validation

- **Gachapon Feature Development**: 5-phase approach
  - Cabinet analysis → Smart contract integration → Frontend implementation → Web3 testing → User experience validation

### 🔄 Pattern Replication Strategy

#### Reference Implementation Approach

1. **Document Successful Patterns**: Create detailed retrospectives for reusable approaches
2. **Systematic Replication**: Use previous session files as implementation guides
3. **Adapt, Don't Recreate**: Modify proven patterns for new contexts
4. **Measure Efficiency**: Track implementation time improvements

#### Proven Pattern Examples

- **Cabinet NFT Integration**: Smart contract → frontend component pattern
- **Marketplace Development**: Escrow → UI → transaction flow approach
- **Randomness Implementation**: Multi-entropy → gas optimization strategies

### ⚡ Build Validation Checkpoints

#### Critical Validation Points

- **Smart Contract Changes**: `cd contracts && npx hardhat compile`
- **Frontend Integration**: `npm run build && npx tsc --noEmit`
- **Web3 Integration**: Test contract interaction after redeployment

#### Proactive Testing Strategy

- **Incremental Builds**: Test builds after each major change, not just at the end
- **Contract Compilation**: Verify Solidity compilation before frontend integration
- **Type Generation**: Regenerate contract types after deployment
- **Network Testing**: Test on KUB Testnet before mainnet deployment

### 🛠️ Multi-Phase Implementation Approach

#### Systematic Phase Breakdown

- **Phase 1**: Analysis & Preparation (10-15%) - Contract review, gas estimation
- **Phase 2**: Core Implementation (40-50%) - Smart contracts, core logic
- **Phase 3**: Integration & Testing (25-30%) - Frontend integration, Web3 testing
- **Phase 4**: Documentation & Cleanup (10-15%) - Deployment docs, user guides

#### Phase Management Best Practices

- **Clear Phase Objectives**: Define specific deliverables for each phase
- **Dependency Mapping**: Identify contract-frontend dependencies upfront
- **Progress Checkpoints**: Validate phase completion before proceeding
- **Issue Tracking**: Update GitHub issues after each phase completion

### 📝 Documentation Standards

#### PR Description Requirements

- **Implementation Summary**: Clear overview of changes made
- **Technical Details**: Smart contract addresses, gas usage, security considerations
- **Before/After Analysis**: Performance impact, gas optimization results
- **Testing Validation**: Build success, contract interaction verification

#### Retrospective Documentation

- **AI Diary**: First-person reflection on approach and decision-making
- **Honest Feedback**: Critical assessment of session efficiency and quality
- **Pattern Recognition**: Identification of reusable patterns and approaches
- **Lessons Learned**: Specific insights for future TuuKeep development

---

## 🛡️ Security & Performance Guidelines

### Smart Contract Security Architecture

**Multi-Layer Security Implementation**:
- **Multi-entropy randomness**: block.prevrandao + timestamp + nonce + sender + requestId
- **Access control**: OpenZeppelin AccessControl with role-based permissions (MINTER, ADMIN, EMERGENCY)
- **Reentrancy protection**: Custom TuuKeepReentrancyGuard for all external calls
- **Input validation**: ValidationLib for comprehensive parameter checking
- **Emergency controls**: Pausable functionality for critical incident response

**Gas Optimization Strategy**:
- **Target**: <50k gas per gameplay transaction
- **Optimizer**: 200 runs for production deployment
- **London EVM**: Avoids PUSH0 opcode for broader compatibility
- **Event optimization**: Structured events for efficient indexing
- **Storage optimization**: Packed structs and efficient data layout

### Performance Optimization (15-min vs 34-min baseline)

**High Efficiency Factors**:

- TodoWrite usage for progress tracking
- Reference pattern from `/docs/retrospective/`
- Systematic 5-phase approach
- Proactive build validation (`npm run build`, `npx tsc --noEmit`)

**Performance Metrics**: 56% faster with pattern replication, 100% build success target

### UI/UX Standards

- WCAG 2.1 AA compliance (4.5:1 contrast)
- shadcn/ui component consistency
- 60fps animations with Framer Motion
- Responsive design for mobile gameplay

---

## 🎮 Gachapon Game System

### Cabinet NFT Mechanics

**Cabinet Ownership Model**:
- Each cabinet is an ERC721 NFT with unique metadata and revenue tracking
- Owners configure cabinet settings: play cost, asset pools, odds multipliers
- Revenue automatically distributed to cabinet owners from player fees
- Dynamic SVG generation for cabinet visual representation

**Gameplay Flow**:
1. **Cabinet Selection**: Players browse available cabinets with different themes/rewards
2. **TuuCoin Integration**: Optional TuuCoin usage for enhanced odds
3. **Multi-Entropy Randomness**: Fair random selection using multiple entropy sources
4. **Asset Distribution**: Digital assets awarded based on configured rarity
5. **Revenue Distribution**: Platform and cabinet owner fee split

### TuuCoin Utility System

**Platform Token Features**:
- ERC20 token for odds modification and platform rewards
- Staking mechanisms for enhanced gameplay benefits
- Governance participation for platform parameter changes
- Deflationary mechanics through gameplay burns

### Marketplace & Trading

**P2P Cabinet Trading**:
- Secondary market for cabinet NFT transfers
- Escrow system for secure transactions
- Revenue history and analytics for informed purchasing
- Automated royalty distribution to original creators

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

**⚠️ CRITICAL: Node.js Version Requirement**

```bash
# ALWAYS verify Node.js version before contract work
node --version  # Must be 22.10.0+ for Hardhat 3.0

# If version is wrong, switch to Node.js 22:
nvm use v22

# After version switch, reinstall dependencies:
cd contracts && rm -rf node_modules && npm install
```

```bash
# Navigate to contracts folder
cd contracts

# Install Hardhat dependencies
npm install

# Compile contracts with Solidity 0.8.28
npx hardhat compile

# Run all tests (Solidity + Node.js)
npx hardhat test

# Deploy to KUB Testnet
npx hardhat ignition deploy ignition/modules/TuuKeepCabinet.ts --network kubTestnet

# Deploy to KUB Mainnet (production)
npx hardhat ignition deploy ignition/modules/TuuKeepCabinet.ts --network kubMainnet

# Test local development
npx hardhat node  # Start local blockchain
npx hardhat run scripts/deploy-local.ts --network localhost
```

### Bitkub Chain Configuration

**Network Details**:

- **KUB Testnet**: Chain ID 25925, Gas optimization enabled
- **KUB Mainnet**: Chain ID 96, Production deployment
- **London EVM**: Compatible with Ethereum tooling, avoids PUSH0 opcode
- **Gas Management**: Auto gas estimation with 1.2x multiplier (testnet), 1.1x (mainnet)

**Deployment Features**:

- **Hardhat 3.0**: Latest EDR simulation with viem integration
- **TypeScript Support**: Full type safety for contract interactions
- **KubScan Verification**: Automated contract verification on Bitkub explorer
- **Gas Reporting**: Detailed gas usage analysis for optimization
- **Ignition Deployment**: State management and deployment tracking

### Web3 Integration

```bash
# Generate contract types for viem (automatic with Hardhat 3.0)
npx hardhat compile  # Generates TypeScript types

# Verify contracts on KubScan
npx hardhat verify --network kubTestnet DEPLOYED_CONTRACT_ADDRESS
npx hardhat verify --network kubMainnet DEPLOYED_CONTRACT_ADDRESS

# Check deployment status
npx hardhat ignition status ignition/deployments/chain-25925/  # Testnet
npx hardhat ignition status ignition/deployments/chain-96/     # Mainnet

# Interact with deployed contracts
npx hardhat run scripts/interact-cabinet.ts --network kubTestnet
```

---

## 📚 Best Practices

### TuuKeep Development Excellence

**Smart Contract Development**:
- **Multi-entropy randomness**: Ensure fair gachapon outcomes
- **Gas optimization**: Target <50k gas per gameplay transaction
- **Security audits**: Multi-layer validation and access control
- **KUB Chain**: Optimize for Bitkub Chain characteristics

**Frontend Integration**:
- **wagmi/viem**: Type-safe blockchain connectivity
- **Real-time events**: Listen for cabinet state changes
- **Mobile optimization**: Responsive gachapon interface
- **Performance**: 60fps animations for smooth gameplay

### TuuKeep Development Best Practices

**Smart Contract Development**:
- **Security First**: Multi-entropy randomness, role-based access control, reentrancy guards
- **Gas Efficiency**: Target <50k gas per gameplay transaction
- **Testing**: Comprehensive Solidity + TypeScript test coverage
- **KUB Chain**: Optimize for Bitkub Chain gas mechanics and London EVM

**Frontend Integration**:
- **wagmi/viem**: Type-safe Web3 integration with React hooks
- **Real-time Updates**: Event listening for cabinet state changes
- **Mobile First**: Responsive design for mobile gachapon gameplay
- **Performance**: Optimize for 60fps animations and smooth interactions

---

## 🔧 Troubleshooting

### Build Issues

```bash
npm run build 2>&1 | grep -A 5 "error"  # Check errors
rm -rf node_modules .next .cache && npm install  # Reset
npx prisma generate  # Reset Prisma
```

### TuuKeep Troubleshooting

**Smart Contract Issues**:
- **Node Version Error**: `nvm use v22 && cd contracts && rm -rf node_modules && npm install`
- **KUB Chain Connection**: Verify RPC URLs and private keys in environment
- **Gas Issues**: Check KUB gas prices, use 1.2x multiplier for testnet
- **Contract Verification**: Use KubScan API for contract verification

**Frontend Issues**:
- **wagmi Connection**: Verify network configuration matches deployed contracts
- **Type Generation**: Regenerate types after contract redeployment
- **Performance**: Monitor gas usage and transaction confirmation times

**Common Fixes**:
- **Port conflicts**: `lsof -i :3000` then `kill -9 [PID]`
- **Build issues**: `rm -rf node_modules .next && npm install && npm run build`
- **Contract sync**: Ensure frontend contract addresses match deployed versions
