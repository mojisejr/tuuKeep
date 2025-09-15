---
## Project Overview

**Project Name**: TuuKeep - Decentralized Gachapon Platform

**Repository**: https://github.com/user/tookeep-kub

**Description**: TuuKeep is a Decentralized Gachapon (TuuKeep) platform built on the blockchain, allowing users to own **Gachapon Cabinet NFTs**. These NFTs are not just collectibles; they are income-generating assets. Cabinet owners can fill their machines with various assets, including other NFTs and crypto tokens, and open them up for players to pay and receive a random item.

**Project Goals**:

- Create a fun NFT gaming platform with a sustainable and engaging economic model
- Generate revenue from selling **Gachapon Cabinet NFTs** and collecting transaction fees from gacha plays
- Build a decentralized ecosystem where cabinet owners earn from their assets
- Provide an engaging gaming experience with blockchain-based randomness and asset management

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
- **Frontend/Framework**: React 18 with TypeScript
- **Styling**: Tailwind CSS with Framer Motion animations (Neon arcade aesthetic)
- **UI Components**: shadcn/ui component library
- **Blockchain Integration**: wagmi & viem for Web3 connectivity
- **Smart Contracts**: Hardhat development environment (nested in monorepo)
- **Blockchain**: Ethereum-compatible networks (Mainnet/Testnet deployment)

### Tech Stack

- **Frontend**: Next.js 14, React 18, TypeScript, Tailwind CSS, Framer Motion
- **UI Framework**: shadcn/ui components with neon arcade theming
- **Web3 Integration**: wagmi, viem, @tanstack/react-query for blockchain interactions
- **Smart Contracts**: Solidity with Hardhat for development and testing
- **Randomness**: On-chain pseudo-randomness using block data
- **Asset Management**: ERC-721 (Cabinet NFTs) and ERC-20 (TuuCoin) standards

### Smart Contract Architecture

- **TuuKeepCabinet.sol** (ERC-721 NFT): Core gachapon cabinet management

  - `depositItems()`: Lock assets (NFTs/tokens) into cabinet escrow
  - `withdrawItems()`: Retrieve unsold items by cabinet owner
  - `setPrice()`: Set play price and payment token for cabinet
  - `play()`: Execute gacha play with optional TuuCoin burning
  - `tokenURI()`: Generate on-chain SVG images with custom names

- **TuuCoin.sol** (ERC-20 Token): Platform meme coin system

  - `mint()`: On-demand minting to players receiving no prize
  - `burn()`: Destroy tokens used for odds modification
  - Decentralized distribution model

- **TuuKeepMarketplace.sol**: P2P cabinet NFT trading

  - Buy/sell cabinet NFTs between users
  - Secondary market functionality

- **Utils/Randomness.sol**: On-chain pseudo-randomness
  - Block-based randomness generation
  - No external oracle dependencies

### Frontend User Journeys & Page Structure

- **User Journey Flows**:
  - **Player Flow**: Home → Cabinet Selection → Connect Wallet → Set TuuCoin Amount → Play Gacha → Receive Prize/TuuCoin
  - **Cabinet Owner Flow**: Connect Wallet → My Cabinets → Deposit Assets → Set Pricing → Manage Cabinet → Withdraw Items
  - **Trading Flow**: Marketplace → Browse Cabinets → Purchase → Own Cabinet → Manage
  - **Platform Owner Flow**: Admin Dashboard → Mint New Cabinets → Monitor Platform

- **Page Structure**:
  - **`/` (Home)**: Display all available Gachapon Cabinet NFTs open for play
  - **`/cabinet/[id]`**: Cabinet detail page with TuuCoin input for odds modification
  - **`/my-cabinets`**: Cabinet owner dashboard for asset and pricing management
  - **`/marketplace`**: Secondary market for cabinet NFT trading
  - **`/mint-cabinet`**: Platform owner exclusive cabinet minting interface

---

## 🎮 Game Mechanics & Data Structures

### Core Game Components

1. **Gachapon Cabinet NFTs**: Income-generating assets with on-chain metadata
2. **Asset Escrow System**: Secure locking of prizes within cabinet contracts
3. **Randomness Engine**: On-chain pseudo-randomness for fair prize distribution
4. **TuuCoin Integration**: Meme coin system for odds modification and rewards

### Data Structures

**GachaItem Struct**:
- `address itemAddress`: Contract address of NFT (ERC-721) or Token (ERC-20)
- `uint256 tokenIdOrAmount`: TokenId for NFTs or amount for tokens
- `uint8 rarity`: Rarity level (1-10, where 1 is rarest)
- `uint256 count`: Number of items remaining
- `string name`: On-chain cabinet name field

### Asset Management System

- **Maximum 10 items per cabinet**: Contract-enforced item limit
- **Escrow Protection**: Assets locked in contract, preventing double-spending
- **Dynamic Pricing**: Cabinet owners set custom play prices and payment tokens
- **Odds Modification**: Players can burn TuuCoin (up to 20% of play price) to improve chances

---

## 💰 Tokenomics & Revenue Model

### Revenue Streams

- **Cabinet NFT Sales**: Limited edition gachapon cabinet NFTs sold by platform owner
- **Transaction Fees**: Platform fee collected from each gacha play transaction
- **Marketplace Fees**: Secondary market trading fees on cabinet transfers

### TuuCoin ($TUU) Economics

- **Minting**: On-demand minting directly to players who receive no prize
- **Burning**: Players burn TuuCoin to modify odds (up to 20% of play price)
- **Decentralized Distribution**: No pre-mine, purely merit-based token distribution
- **Utility**: Primary use for odds improvement and platform governance

### User Roles & Economics

- **Platform Owner**: Sells cabinet NFTs, collects transaction fees
- **Cabinet Owner**: Earns revenue from gacha plays, manages asset deposits
- **Player**: Pays to play, receives prizes or TuuCoin, can modify odds

---

## 🎯 Implementation Phases

### Phase 1: Smart Contract Development & Testing

1. **Smart Contract Development**: Design and implement all contracts in `/contracts` folder
2. **Local Testing**: Comprehensive unit tests with Hardhat
3. **Testnet Deployment**: Deploy to Sepolia for realistic testing
4. **Mainnet Deployment**: Production deployment of battle-tested contracts

### Phase 2: Web Application Development

1. **Project Setup**: Next.js monorepo with nested Hardhat project
2. **Blockchain Integration**: Connect wagmi and viem with Next.js
3. **Service Layer**: Abstract smart contract interactions
4. **UI/UX Development**:
   - Neon arcade aesthetic with shadcn/ui
   - Framer Motion animations
   - Responsive design across all devices
5. **End-to-End Testing**: Complete user journey validation
6. **Production Deployment**: Launch on production server

### Code Organization (Monorepo)

- **`/` (root)**: Next.js Project
- **`/contracts`**: Hardhat Project with Solidity contracts
- **`/app`**: Next.js App Router pages
- **`/components`**: UI components (shared, page-specific)
- **`/services`**: Blockchain interaction abstractions
- **`/types`**: TypeScript interfaces and type definitions

---

## ⚠️ CRITICAL SAFETY RULES

### NEVER MERGE PRS YOURSELF

**DO NOT** use any commands to merge Pull Requests, such as `gh pr merge`. Your role is to create a well-documented PR and provide the link to the user.

**ONLY** provide the PR link to the user and **WAIT** for explicit user instruction to merge. The user will review and merge when ready.

### DO NOT DELETE CRITICAL FILES

You are **FORBIDDEN** from deleting or moving critical files and directories in the project. This includes, but is not limited to: `.env`, `.git/`, `node_modules/`, `package.json`, `prisma/schema.prisma`, and the main project root files. If a file or directory needs to be removed, you must explicitly ask for user permission and provide a clear explanation.

### HANDLE SENSITIVE DATA WITH CARE

You must **NEVER** include sensitive information such as API keys, passwords, or user data in any commit messages, Pull Request descriptions, or public logs. Always use environment variables for sensitive data. If you detect sensitive data, you must alert the user and **REFUSE** to proceed until the information is properly handled.

**Critical Environment Variables**:

- `PRIVATE_KEY`: Wallet private key for contract deployment
- `INFURA_PROJECT_ID`: Infura API key for blockchain connectivity
- `ETHERSCAN_API_KEY`: For contract verification
- `NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID`: WalletConnect configuration
- `NEXT_PUBLIC_CONTRACT_ADDRESS_CABINET`: Deployed cabinet contract address
- `NEXT_PUBLIC_CONTRACT_ADDRESS_TUUCOIN`: Deployed TuuCoin contract address

### STICK TO THE SCOPE

You are instructed to focus **ONLY** on the task described in the assigned Issue. Do not perform any refactoring, code cleanup, or new feature development unless it is explicitly part of the plan. If you encounter an opportunity to improve the code outside of the current scope, you must create a new task and discuss it with the user first.

### SMART CONTRACT SAFETY

**DO NOT** deploy smart contracts to mainnet without thorough testing on testnet. Always verify contract addresses and test all functions on testnet before mainnet deployment. Any changes to contract logic must be thoroughly tested using Hardhat test suite (`npx hardhat test`).

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

## 🛡️ Security Implementation Methodology

_Based on comprehensive security audit sessions documented in retrospectives_

### Systematic Security Audit Approach

**8-Phase Security Audit Process** (31-minute comprehensive audits):

1. **Infrastructure Analysis** (2-3 min): Environment variables, database schema, authentication
2. **Core Endpoint Analysis** (5-8 min): Input validation, rate limiting, error handling, authorization
3. **Data Integrity Analysis** (3-5 min): Transaction security, data flow assessment, logging
4. **Compliance Assessment** (3-5 min): PCI DSS, GDPR, industry standards
5. **Vulnerability Testing** (5-8 min): Injection prevention, authentication bypass, authorization
6. **Security Implementation** (8-12 min): Rate limiting, input validation, error hardening
7. **Build Validation** (2-3 min): TypeScript compilation, dependency validation
8. **Documentation & Reporting** (3-5 min): Security audit report, compliance metrics

### Enterprise-Grade Security Measures

#### Critical Security Implementations

- **Rate Limiting**: 15-minute windows, configurable limits per endpoint
- **Input Validation**: Comprehensive Zod schemas for all API endpoints
- **Secure Error Handling**: Generic error responses prevent information disclosure
- **Webhook Security**: Signature validation with timestamp-based replay protection

### Security Compliance Metrics

**Measurable Improvements from Security Audits**:

- **PCI DSS Compliance**: 65% → 85% improvement documented
- **Critical Vulnerabilities**: 5 critical issues → 0 critical issues
- **High-Priority Issues**: 8 high-priority → 2 high-priority resolved
- **Security Score**: Significant improvement in enterprise security standards

### Security Best Practices from Retrospectives

**Key Security Areas**:

- **Webhook Security**: Validate signatures, prevent replay attacks, never log secrets
- **Payment System**: Server-side validation, discount verification, transaction integrity
- **Error Handling**: Generic error responses, sanitized logging

---

## 🎨 UI/UX Design Integration Guidelines

_Based on style refactoring and accessibility improvement sessions_

### Visual Design Validation Requirements

**CRITICAL**: Visual design quality is equally important as functional implementation, especially for customer-facing features.

#### Pre-Implementation Design Checklist

```markdown
✅ Color contrast validation (WCAG 2.1 AA compliance)
✅ Accessibility standards verification
✅ Responsive design across device sizes
✅ Typography hierarchy consistency
✅ Animation performance optimization
✅ Reduced motion preference support
```

#### Design Quality Assurance Process

**3-Phase Approach**:

1. **Design System Integration**: Follow component patterns, centralized utilities (60% duplication reduction)
2. **Accessibility Implementation**: WCAG 2.1 AA compliance (4.5:1 contrast), keyboard navigation, screen reader support, reduced motion
3. **Performance Optimization**: 60fps animations, bundle size monitoring, critical CSS, responsive images

### Centralized Styling Architecture

- **Utility-Based System**: Centralized styling utilities in `src/utils/campaignStyles.ts`
- **TypeScript Interfaces**: Proper typing for styling configurations
- **Accessibility Integration**: Built-in WCAG compliance and reduced motion support
- **60% Duplication Reduction**: Proven efficiency through centralized approach

### Marketing Component Requirements

**Campaign Elements**: High visual impact, enhanced contrast for promotional text, clear visual hierarchy, A/B testing ready

### Design Review Integration

**Visual Review Steps**: Browser preview, contrast analysis, multi-device testing, accessibility testing, motion testing

**Common Pitfalls to Avoid**: Poor color choices, inconsistent spacing, animation overuse, desktop-only thinking, accessibility afterthoughts

---

## ⚡ Efficiency Patterns & Performance Optimization

_Based on documented performance improvements from retrospective analysis_

### 🏃‍♂️ 15-Minute Implementation Strategy

**Results**: 15-minute implementations vs 34+ minute baseline

**Prerequisites**: Reference pattern, TodoWrite initialized, component structure analyzed, integration points identified

**Speed Optimization Techniques**:

1. **Pattern Recognition**: 56% faster when following proven patterns from `/docs/retrospective/`
2. **MultiEdit**: Batch multiple edits instead of sequential single edits
3. **Systematic Analysis**: 2-3 minute analysis of target areas and integration points
4. **Build Validation**: `npm run build` after major changes, `npx tsc --noEmit` for type checking

### 📊 Performance Benchmarks

#### Implementation Time Comparisons

| Task Type             | First Implementation | Pattern Replication | Improvement |
| --------------------- | -------------------- | ------------------- | ----------- |
| UI Consolidation      | 34 minutes           | 15 minutes          | 56% faster  |
| Component Refactoring | 45 minutes           | 20 minutes          | 56% faster  |
| API Migration         | 135 minutes          | 75 minutes          | 44% faster  |
| Database Debugging    | 45 minutes           | 25 minutes          | 44% faster  |
| Security Audit        | 60+ minutes          | 31 minutes          | 48% faster  |
| Style Refactoring     | 70+ minutes          | 55 minutes          | 21% faster  |

#### Efficiency Factor Analysis

**High Efficiency Sessions** (15-20 minutes):

- ✅ TodoWrite usage for progress tracking
- ✅ Reference pattern available
- ✅ Clear component structure understanding
- ✅ Systematic 5-phase approach
- ✅ Proactive build validation

**Low Efficiency Sessions** (45+ minutes):

- ❌ No reference pattern
- ❌ Schema assumptions without verification
- ❌ Working directly on main branch
- ❌ Build testing only at end
- ❌ Complex dependency analysis needed

### 🎯 High-Impact Optimization Areas

#### 1. TodoWrite Integration ROI

- **Setup Time**: 2-3 minutes
- **Visibility Benefit**: Real-time progress tracking
- **Accountability**: Prevents skipping critical steps
- **Stakeholder Communication**: Clear progress indicators
- **Proven Results**: 56% faster implementations documented

#### 2. Reference Pattern Utilization

- **Pattern Documentation**: Create detailed retrospectives
- **Pattern Library**: Maintain `/docs/retrospective/` as reference
- **Systematic Replication**: Follow proven approaches exactly
- **Context Adaptation**: Modify only necessary elements

#### 3. Tool Optimization

- **Efficient Pattern**: Read (targeted) → MultiEdit (batch) → Build (validation)
- **Avoid**: Multiple single Edits → Multiple Reads → Late build testing

#### 4. Workflow Adherence

- **Branch Management**: Always create feature branches
- **Incremental Testing**: Build validation at each phase
- **Documentation Standards**: Comprehensive PR descriptions
- **Issue Tracking**: Real-time GitHub issue updates

### 🔄 Continuous Improvement Framework

**Session Performance Tracking**: Track implementation time, document efficiency factors, identify workflow violations, measure pattern success rates

**Pattern Development Lifecycle**: Novel Implementation → Pattern Recognition → Pattern Refinement → Pattern Maturation (sub-20-minute implementations)

### 📈 Success Metrics & Performance Indicators

#### Key Performance Indicators (KPIs)

- **Implementation Speed**: Target <20 minutes for standard refactoring tasks
- **Pattern Replication Success**: 56% time reduction when following proven patterns
- **Build Success Rate**: 100% successful builds after implementation
- **TodoWrite Utilization**: 100% usage for complex multi-phase tasks
- **Security Compliance**: 85%+ PCI DSS compliance maintenance
- **Code Quality**: Zero TypeScript errors in final implementations

#### Session Quality Assessment

- **Excellent (9-10/10)**: <20 min, pattern replication, zero issues
- **Good (7-8/10)**: 20-35 min, some iterations, minor issues
- **Average (5-6/10)**: 35-60 min, multiple iterations, troubleshooting
- **Below Average (<5/10)**: >60 min, major blockers, incomplete

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

# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test

# Deploy to local network
npx hardhat node
npx hardhat run scripts/deploy.js --network localhost

# Deploy to testnet
npx hardhat run scripts/deploy.js --network sepolia
```

### Web3 Integration

```bash
# Generate contract types
npx typechain --target ethers-v5 --out-dir types/contracts 'contracts/artifacts/**/*.json'

# Verify contracts on Etherscan
npx hardhat verify --network mainnet DEPLOYED_CONTRACT_ADDRESS
```

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

## 📚 Best Practices from Retrospectives

_Lessons from 10+ development sessions in `/docs/retrospective/`_

### 🎯 TodoWrite Integration Best Practices

**Results**: **15-minute implementations** vs 34+ minute sessions

**When to Use**: Complex multi-step tasks (3+ phases), multi-component refactoring, full-stack implementations, large refactoring projects, security audits, campaign development, database migrations

**Workflow Pattern**:

1. Break into 5-12 manageable todos
2. Mark exactly ONE todo in_progress → completed
3. Provides real-time visibility and accountability
4. Enables accurate time estimation

**Proven Benefits**: 56% faster implementation, reduces context switching, prevents missing steps, ensures comprehensive testing

#### Advanced TodoWrite Patterns

- **Security Implementations**: 8-phase systematic approach (31-minute completion)

  - Phases 1-2: Infrastructure & Core Endpoint Analysis
  - Phases 3-4: Data Integrity & Compliance Assessment
  - Phases 5-6: Vulnerability Testing & Security Implementation
  - Phases 7-8: Build Validation & Documentation

- **UI/UX Refactoring**: 4-phase centralized styling development
  - WCAG compliance audit → Centralized utilities → Component integration → Performance optimization

### 🔄 Pattern Replication Strategy

#### Reference Implementation Approach

1. **Document Successful Patterns**: Create detailed retrospectives for reusable approaches
2. **Systematic Replication**: Use previous session files as implementation guides
3. **Adapt, Don't Recreate**: Modify proven patterns for new contexts
4. **Measure Efficiency**: Track implementation time improvements

#### Proven Pattern Examples

- **UI Consolidation**: Reward card → chip integration (achieved 56% speed improvement)
- **Component Refactoring**: Systematic removal and integration approaches
- **API Updates**: Phase-by-phase endpoint migration strategies

### ⚡ Build Validation Checkpoints

#### Critical Validation Points

- **Schema Changes**: `npm run build && npx tsc --noEmit`
- **API Modifications**: `npm run build 2>&1 | grep -A 5 "error"`
- **Large Refactoring**: `npx prisma generate && npm run build`

#### Proactive Testing Strategy

- **Incremental Builds**: Test builds after each major change, not just at the end
- **TypeScript Validation**: Run `npx tsc --noEmit` for pure type checking
- **Dependency Verification**: Check imports and exports after file restructuring
- **Database Sync**: Verify `npx prisma generate` after schema changes

### 🗄️ Schema Investigation Protocol

#### Before Implementation Checklist

1. **Verify Database Schema**: Always check actual Prisma schema definitions
2. **Trace Data Structures**: Follow interface definitions through the codebase
3. **Validate Field Names**: Don't assume field naming conventions
4. **Check Relationships**: Understand model relationships before querying

#### Common Schema Pitfalls

- **Assumption Errors**: Making assumptions about field names/structures
- **Interface Misalignment**: Frontend interfaces not matching database schema
- **Relationship Complexity**: Not understanding foreign key relationships
- **Type Mismatches**: TypeScript interfaces not reflecting actual data structures

### 🔧 Multi-Phase Implementation Approach

#### Systematic Phase Breakdown

- **Phase 1**: Analysis & Preparation (10-15%)
- **Phase 2**: Core Implementation (40-50%)
- **Phase 3**: Integration & Testing (25-30%)
- **Phase 4**: Documentation & Cleanup (10-15%)

#### Phase Management Best Practices

- **Clear Phase Objectives**: Define specific deliverables for each phase
- **Dependency Mapping**: Identify cross-phase dependencies upfront
- **Progress Checkpoints**: Validate phase completion before proceeding
- **Issue Tracking**: Update GitHub issues after each phase completion

### 🔒 Smart Contract Best Practices

#### Contract Security Guidelines

- **Access Control**: Implement proper owner/admin controls for sensitive functions
- **Reentrancy Protection**: Use ReentrancyGuard for functions handling external calls
- **Integer Overflow**: Use SafeMath or Solidity 0.8+ built-in overflow protection
- **Gas Optimization**: Minimize storage operations and external calls

#### Testing Strategy

1. **Unit Tests**: Test each contract function in isolation
2. **Integration Tests**: Test complete user workflows
3. **Edge Cases**: Test boundary conditions and error scenarios
4. **Gas Analysis**: Monitor gas usage and optimize expensive operations

### 📝 Documentation Standards

#### PR Description Requirements

- **Implementation Summary**: Clear overview of changes made
- **Technical Details**: Specific technical implementation notes
- **Before/After Analysis**: Impact assessment and improvement metrics
- **Testing Validation**: Build success and functionality verification

#### Retrospective Documentation

- **AI Diary**: First-person reflection on approach and decision-making
- **Honest Feedback**: Critical assessment of session efficiency and quality
- **Pattern Recognition**: Identification of reusable patterns and approaches
- **Lessons Learned**: Specific insights for future implementation improvement

---

## 🔧 Troubleshooting

### Common Issues

#### Build Failures

```bash
# Check for type errors or syntax issues
npm run build 2>&1 | grep -A 5 "error"

# Clear cache and reinstall dependencies
rm -rf node_modules .next .cache
npm install

# Reset Prisma client
npx prisma generate
```

#### Contract Deployment Issues

```bash
# Clean and recompile contracts
npx hardhat clean
npx hardhat compile

# Check deployment script
node scripts/deploy.js

# Verify contract on testnet first
npx hardhat run scripts/deploy.js --network sepolia
```

#### Smart Contract Issues

**Common Contract Deployment Issues:**

- Gas estimation failures during deployment
- Contract verification failures on Etherscan
- ABI mismatch between frontend and deployed contracts
- Network configuration problems

**Diagnosis and Resolution:**

- Check gas prices: Use tools like ETH Gas Station for current rates
- Verify network configuration in Hardhat config
- Regenerate contract types after redeployment: `npx typechain`
- Test on local network first: `npx hardhat node`

**Prevention strategies:**

- Always test contracts thoroughly on local network
- Use consistent compiler versions across environments
- Maintain proper contract verification scripts
- Keep deployment addresses organized per network

#### Web3 Integration Errors

_Contract ABI and type safety are critical for Web3 applications_

**Common Integration Issues:**

- **ABI Sync**: `npx typechain --target ethers-v5 --out-dir types/contracts`
- **Type Validation**: `npm run build && npx tsc --noEmit`
- **Contract Types**: Regenerate types after contract redeployment

**Web3 Integration Protocol:**

1. **Never assume contract addresses** - Always verify deployed addresses
2. **Trace contract interactions** - Follow transaction flows through wagmi hooks
3. **Verify network compatibility** - Check contract deployment on target networks
4. **Test incremental changes** - Run build after each Web3 integration change

**Common pitfalls**: Stale contract addresses, outdated ABIs, network mismatches

#### Web3 Connection Issues

```bash
# Check wallet connection
# Verify MetaMask is installed and connected
# Ensure correct network is selected

# Check contract addresses
echo "Verify deployed contract addresses match frontend configuration"

# Test contract interactions
# Use Hardhat console for contract debugging
npx hardhat console --network localhost
```

#### Port Conflicts

```bash
# Find the process using port 3000
lsof -i :3000

# Kill the process
kill -9 [PID]

# Use alternative port
npm run dev -- -p 3001
```

#### Blockchain Network Issues

```bash
# Check network connectivity
curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' https://mainnet.infura.io/v3/YOUR_PROJECT_ID

# Verify wallet balance
# Check if wallet has sufficient ETH for gas fees

# Test transaction simulation
# Use tools like Tenderly for transaction debugging
```

#### Security Implementation Issues

_From comprehensive security audit retrospectives_

**Rate Limiting Configuration Missing:**

- Check patterns in `src/middleware/rate-limiter.ts`
- API config: `{ windowMs: 15 * 60 * 1000, max: 100 }`
- Admin config: `{ windowMs: 15 * 60 * 1000, max: 20 }`

**Webhook Security Hardening:**

- Never log webhook secrets in error messages
- Use generic error responses to prevent information disclosure
- Implement timestamp-based replay protection (5-minute window)
- Use `stripe.webhooks.constructEvent()` for signature validation

**Input Validation Enhancement:**

- Implement comprehensive Zod schemas for all API endpoints
- Example: Payment validation with amount limits, currency restrictions, UUID validation

#### System Integration Issues

_From reward configuration and campaign implementation sessions_

**RewardConfiguration Integration:**

- Always check existing database records first: `npx prisma studio --port 5555`
- Create temporary validation scripts for testing database operations
- Use `PrismaClient` for isolated testing of specific queries

**Campaign System Testing:**

- Test campaign eligibility detection
- Verify PaymentHistory queries for first payment detection
- Validate campaign discount application in Stripe integration
- Debug with API calls to campaign endpoints

#### Visual Design and Accessibility Issues

_From UI/UX refactoring sessions_

**Color Contrast and Accessibility Problems:**

- Use automated contrast checking tools
- Validate WCAG 2.1 AA compliance (4.5:1 ratio minimum)
- Test with screen readers when possible
- Check banner text readability and promotional element contrast
- Test reduced motion preferences

**Styling System Conflicts:**

- Avoid duplication with centralized utilities
- Implement proper TypeScript interfaces for styling configs
- Follow existing component patterns and design tokens
- Use `src/utils/campaignStyles.ts` and `src/components/common/`

#### Database Migration and Schema Issues

_From database migration and system reset sessions_

**Migration Safety Protocol:**

- Always create comprehensive backups before major changes
- Preserve critical data (Card and Prompt tables)
- Use timestamped backup files: `backup-$(date +%Y-%m-%d-%H%M).db`
- Use `npx prisma db seed` for critical data restoration

**Schema Assumptions Prevention:**

- Never assume field names without verification
- Always check actual Prisma schema definitions
- Trace data structures through the entire codebase
- Use `grep` commands to trace field usage across codebase

### Performance Monitoring

- **Core Web Vitals**: Monitor LCP (<2.5s), FID (<100ms), CLS (<0.1)
- **Transaction Times**: Monitor blockchain transaction confirmation times
- **Gas Usage**: Track and optimize contract gas consumption
- **Web3 Connection**: Monitor wallet connection reliability and RPC response times
- **Contract Interaction**: Track success rates of contract function calls
- **Error Rates**: Monitor failed transactions and connection issues
