---
## Project Overview

**Project Name**: MiMiVibes - AI-Powered Tarot Reading Platform

**Repository**: https://github.com/mojisejr/mimivibe-ai.git

**Description**: แพลตฟอร์มดูไพ่ทาโรต์ออนไลน์ที่ขับเคลื่อนด้วย AI ให้บริการการทำนายแบบส่วนตัวผ่าน "แม่หมอมีมี่" ผู้เชี่ยวชาญด้านไพ่ทาโรต์ AI ระบบใช้เทคโนโลยี Multi-LLM (OpenAI GPT-4 + Google Gemini) ร่วมกับ LangGraph workflow เพื่อสร้างการทำนายที่มีคุณภาพสูงและเป็นธรรมชาติ

**Project Goals**:

- สร้างประสบการณ์การทำนายไพ่ทาโรต์ที่เข้าถึงได้ง่าย น่าเชื่อถือ และมีคุณภาพสูงผ่านเทคโนโลยี AI
- รับประกันคุณภาพการทำนายด้วยระบบ Multi-LLM และ LangGraph workflow
- สร้างรายได้ที่ยั่งยืนผ่านระบบ credit และ gamification ครบครัน
- รักษาความปลอดภัยและความเชื่อถือของผู้ใช้ด้วยระบบรักษาความปลอดภัยระดับองค์กร

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
- **API Layer**: Next.js API Routes (39+ endpoints)
- **Database**: PostgreSQL (Production) / SQLite (Development) with Prisma ORM
- **File Storage**: Vercel Static Assets
- **Styling**: Tailwind CSS with Framer Motion animations
- **Authentication**: Clerk Auth (Multi-provider support)
- **Data Validation**: Zod with custom validation schemas

### Tech Stack

- **Frontend**: Next.js 14, React 18, TypeScript, Tailwind CSS, Framer Motion, Clerk Auth
- **Backend**: Node.js (Vercel Serverless), Prisma ORM, PostgreSQL, Stripe Payments
- **AI Integration**: OpenAI GPT-4-turbo, Google Gemini 2.0 Flash, LangGraph workflow engine
- **Database**: PostgreSQL via Vercel/Supabase with Prisma migrations
- **File Storage**: Vercel Edge Network CDN
- **Authentication**: Clerk with Google, Facebook, Email providers

### Backend API Routes

- **Reading System** (`/api/readings/`): Core tarot reading functionality

  - `ask.ts`: Generate new tarot readings with AI workflow
  - `save.ts`: Save completed readings to user history
  - `history.ts`: Retrieve user's reading history with pagination

- **User Management** (`/api/user/`): User profile and progression

  - `stats.ts`: User statistics, level, and experience tracking
  - `credits.ts`: Credit balance management (stars, coins, free points)
  - `level-check.ts`: Level progression and prestige system
  - `prestige.ts`: Prestige system for level 100+ users

- **Payment System** (`/api/payments/`): Stripe integration

  - `create-payment-intent.ts`: Stripe payment processing
  - `webhook.ts`: Stripe webhook for payment confirmations
  - `history.ts`: Payment transaction history

- **Gamification** (`/api/achievements/`, `/api/credits/`): Achievement and reward system

  - `progress.ts`: Track user achievement progress
  - `claim.ts`: Claim earned achievements
  - `spend.ts`: Process credit spending transactions

- **Admin System** (`/api/admin/`): Administrative functions
  - Campaign management, user analytics, system monitoring

### Frontend User Journeys

- **User Journey Flows**:
  - **Tarot Reading Flow**: Landing → Sign Up/Login → Ask Question → Card Selection → AI Generation → Reading Display → Save/Share
  - **Payment Flow**: Credit Check → Package Selection → Stripe Payment → Credit Addition → Confirmation
  - **Gamification Flow**: Complete Actions → Earn XP/Coins → Level Up → Unlock Achievements → Exchange Coins → Prestige System
  - **History Management**: Reading History → Search/Filter → Detail View → Delete/Favorite → Export Options

---

## 🤖 AI System Architecture

### LangGraph Workflow (4-Node State Machine)

1. **Question Filter Node**: คัดกรองความเหมาะสมของคำถาม, ตรวจสอบเนื้อหาและความชัดเจน
2. **Question Analysis Node**: วิเคราะห์อารมณ์ (mood), หัวข้อ (topic), และกรอบเวลา (period)
3. **Card Selection Node**: สุ่มไพ่จากสำรับ Rider-Waite (78 ใบ) รองรับ 3-5 ใบ
4. **Reading Generation Node**: สร้างการทำนายด้วยบุคลิก "แม่หมอมีมี่"

### Multi-LLM Provider System

- **Primary Provider**: OpenAI GPT-4-turbo (default)
- **Fallback Provider**: Google Gemini 2.0 Flash
- **Provider Abstraction**: LLMProvider interface with automatic fallback
- **Token Limits**: 4096 tokens for complex readings
- **Prompt Management**: Encrypted prompt system with version control

### Prompt Templates

- **Question Filter**: คัดกรองคำถามที่เหมาะสมสำหรับการทำนาย
- **Question Analysis**: วิเคราะห์บริบทและอารมณ์ของคำถาม
- **Reading Agent**: บุคลิก "แม่หมอมีมี่" สำหรับการทำนายที่อบอุ่นและเป็นกันเอง

---

## 💳 Payment & Credit System

### Credit Types

- **Stars (⭐)**: เครดิตหลักที่ซื้อด้วยเงินจริง (1 star = 1 reading)
- **Free Points (🎁)**: เครดิตฟรีจากกิจกรรมและ achievements
- **Coins (🪙)**: สกุลเงินเกมสำหรับแลกเปลี่ยน (15 coins = 1 free point)

### Stripe Integration

- **Currency**: Thai Baht (THB)
- **Packages**: Starter (99 THB/10 credits), Popular (199 THB/25 credits), Premium (399 THB/60 credits)
- **Webhook**: Real-time payment status updates
- **Security**: PCI DSS compliant with secure payment processing

---

## 🎮 Gamification System

### Level & Experience System

- **Level Progression**: level \* 100 EXP required per level
- **Max Level**: 100 (Prestige system available)
- **EXP Sources**: Readings (+10), Reviews (+5), Achievements (variable)
- **Prestige**: Reset to level 1 with permanent bonuses at level 100

### Achievement System (20 Achievements)

- **Reading Milestones**: FIRST_READING, READING_MASTER, ULTIMATE_MASTER
- **Engagement**: REVIEWER, SOCIAL_BUTTERFLY, REFERRAL_MASTER
- **Progression**: LEVEL_ACHIEVER, PRESTIGE_PIONEER
- **Special**: EARLY_BIRD, WEEKEND_WARRIOR, NIGHT_OWL

### Exchange System

- **Uniswap-style Interface**: Modern crypto-inspired design
- **Exchange Rate**: 15 coins = 1 free point
- **Transaction History**: Complete exchange tracking

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

- `DATABASE_URL`, `CLERK_SECRET_KEY`, `STRIPE_SECRET_KEY`
- `OPENAI_API_KEY`, `GOOGLE_GENERATIVE_AI_API_KEY`
- `PROMPT_ENCRYPTION_KEY`, `STRIPE_WEBHOOK_SECRET`

### STICK TO THE SCOPE

You are instructed to focus **ONLY** on the task described in the assigned Issue. Do not perform any refactoring, code cleanup, or new feature development unless it is explicitly part of the plan. If you encounter an opportunity to improve the code outside of the current scope, you must create a new task and discuss it with the user first.

### AI SYSTEM SAFETY

**DO NOT** modify AI prompts or LangGraph workflow without explicit permission. The prompt system uses AES-256-GCM encryption and version control. Any changes to AI behavior must be thoroughly tested using the prompt test runner (`npm run prompt:test`).

### CONFLICT PREVENTION & BRANCH SAFETY

**MANDATORY STAGING BRANCH SYNC**: Before any implementation (`=impl`), you **MUST** ensure the local staging branch is synchronized with remote origin. Use `git fetch origin && git checkout staging && git pull origin staging` to sync.

**STAGING-FIRST WORKFLOW**: All implementations work exclusively with staging branch. **NEVER** create PRs to main branch or interact with main branch during `=impl`. The user will handle main branch merges manually.

**FORCE PUSH RESTRICTIONS**: Only use `git push --force-with-lease` when absolutely necessary. **NEVER** use `git push --force` as it can overwrite team members' work. Always prefer clean rebasing and conflict resolution.

**HIGH-RISK FILE COORDINATION**: Files requiring team coordination include:

- `src/app/page.tsx`, `src/app/layout.tsx` (main app structure)
- `package.json`, `package-lock.json` (dependency management)
- `prisma/schema.prisma` (database schema)
- `.env.example`, configuration files
- API route files with shared dependencies

**EMERGENCY CONFLICT RESOLUTION**: If conflicts are detected during implementation:

1. **STOP** all operations immediately
2. **ALERT** the user about the conflict
3. **PROVIDE** clear resolution steps
4. **WAIT** for user approval before proceeding
5. **DOCUMENT** the resolution in commit messages

### AUTOMATED WORKFLOW SAFETY

**BRANCH NAMING ENFORCEMENT**: All feature branches **MUST** follow the pattern `feature/[issue-number]-[description]` (e.g., `feature/123-user-authentication`).

**COMMIT MESSAGE STANDARDS**: All commits **MUST** include:

- Clear, descriptive subject line (max 50 characters)
- Detailed body explaining the changes (if needed)
- Reference to related issue number
- Type prefix: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`

**PR CREATION REQUIREMENTS**: All Pull Requests **MUST** include:

- Comprehensive description of changes
- Link to related GitHub issue
- Testing instructions
- Breaking changes documentation (if any)
- Conflict resolution summary (if applicable)

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
- **Source**: All feature branches **MUST** be created from `staging` branch
- **Flow**: `feature/[issue] → staging → main`
- **Example**: `feature/27-deployment-production-implementation`
- **Auto-sanitization**: Removes special characters, converts to kebab-case

##### Commit Message Standards

- **Format**: `[type]: [description] (#[issue-number])`
- **Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
- **Example**: `feat: implement user authentication system (#25)`

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

**Staging PR Requirements**:

- **Reviewers**: Minimum 1 reviewer approval required
- **Automated Checks**: Build validation, type checking, linting
- **Context File**: Must reference `staging-context.md` with deployment details
- **Testing**: Feature testing in staging environment
- **Documentation**: Implementation details and staging deployment notes

**Production PR Requirements**:

- **Reviewers**: Minimum 2 reviewer approvals required
- **Automated Checks**: Full test suite, security scans, performance validation
- **Context File**: Staging validation results and production readiness checklist
- **Testing**: Comprehensive staging validation and production deployment testing
- **Documentation**: Production deployment summary and rollback procedures

**General Quality Standards**:

- **Security Review**: All PRs undergo security validation for sensitive changes
- **Rollback Readiness**: Clear instructions for reverting changes if needed
- **Audit Trail**: Complete documentation of changes and approval process

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
npm run type-check
```

### Database Management

```bash
# Generate Prisma client
npx prisma generate

# Run database migrations
npx prisma migrate dev

# Reset database
npx prisma migrate reset

# Seed database
npx prisma db seed
```

### AI Prompt Management

```bash
# List all prompts
npm run prompt:list

# Update prompt
npm run prompt:update

# Test prompts
npm run prompt:test

# Analyze prompt performance
npm run prompt:analyze
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

### 🛡️ Database Best Practices

#### PostgreSQL Sequence Management

- **Check Sequence**: `SELECT last_value FROM "TableName_id_seq";`
- **Reset Sequence**: `SELECT setval('"TableName_id_seq"', COALESCE(MAX(id), 0) + 1) FROM "TableName";`
- **Common Issue**: Auto-increment sequences become desynchronized after manual insertions

#### Debugging Strategy

1. **Temporary Scripts**: Create debugging scripts instead of modifying main code
2. **Isolation Testing**: Test specific database operations in isolation
3. **Sequence Verification**: Check auto-increment sequences after data manipulation
4. **Transaction Safety**: Use transactions for multi-step database operations

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

#### Database Issues

```bash
# Reset database connection
npx prisma db push --force-reset

# Check database connection
npx prisma db pull

# Regenerate Prisma client
npx prisma generate
```

#### PostgreSQL Sequence Issues

_From retrospective: "Auto-increment sequences can become desynchronized in PostgreSQL"_

**Common symptoms:**

- Unique constraint violations on primary key fields during seeding
- Database insertion failures with "duplicate key value violates unique constraint"
- Auto-increment sequence out of sync with actual data

**Diagnosis and Resolution:**

- Check sequence: `SELECT last_value FROM "TableName_id_seq";`
- Check max ID: `SELECT MAX(id) FROM "TableName";`
- Reset sequence: `SELECT setval('"TableName_id_seq"', COALESCE(MAX(id), 0) + 1) FROM "TableName";`

**Prevention strategies:**

- Always reset sequences after manual data insertion
- Use `COALESCE(MAX(id), 0) + 1` to handle empty tables
- Check sequence synchronization after database migrations
- Create debugging scripts for complex sequence issues

#### TypeScript Compilation Errors

_From retrospective: "Schema investigation prevents TypeScript errors"_

**Common Interface Misalignments:**

- **Schema Check**: `cat prisma/schema.prisma | grep -A 10 "model ModelName"`
- **Type Validation**: `npx tsc --noEmit --strict`
- **Fresh Types**: `npx prisma generate && npx tsc --noEmit`

**Schema Investigation Protocol:**

1. **Never assume field names** - Always check actual schema definitions
2. **Trace data structures** - Follow interfaces through `useProfile` hooks and API responses
3. **Verify relationships** - Check foreign key relationships in Prisma schema
4. **Test incremental changes** - Run type checking after each interface modification

**Common pitfalls**: Assuming field names without verification, interface mismatches between API and frontend

#### AI System Issues

```bash
# Test AI providers
npm run prompt:test

# Check API keys
echo $OPENAI_API_KEY | head -c 10
echo $GOOGLE_GENERATIVE_AI_API_KEY | head -c 10

# Verify prompt encryption
npm run prompt:list
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

#### Payment System Issues

```bash
# Test Stripe webhook
stripe listen --forward-to localhost:3000/api/payments/webhook

# Verify Stripe keys
echo $STRIPE_SECRET_KEY | head -c 10
echo $STRIPE_WEBHOOK_SECRET | head -c 10
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
- **API Response Times**: Target <500ms average
- **Database Queries**: Monitor slow queries via Prisma logs
- **AI Response Times**: Track LLM provider performance
- **Error Rates**: Monitor via Vercel analytics and custom logging
