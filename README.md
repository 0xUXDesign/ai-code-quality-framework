[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

# AI Code Quality Framework

**Ship production-quality AI-generated code — without slowing down.**

I manage a team of 15+ engineers building a product that processes $100M+ daily volume. We use Claude Code for nearly everything. Six months in, I noticed a pattern: AI coding tools are incredibly fast, but they silently accumulate debt that kills you later — unused imports, orphan exports, copy-pasted logic, tests that can't actually fail, and a codebase that grows 3x faster than it should.

This framework fixes that with three layers:

1. **Enforcement** — Hooks, CI gates, and mutation testing catch bad code mechanically
2. **Intelligence** — Codebase-aware AI prevents bad decisions before they happen
3. **Discipline** — Slash commands structure the entire development lifecycle

The result: your AI-assisted codebase gets *cleaner* over time instead of rotting.

## The Development Lifecycle

This is the workflow that runs our team daily. Each step has a slash command that does the heavy lifting:

```
/plan          →  Explore codebase, estimate LOC, get approval
/plan-review   →  Deep review of the plan before writing code
/sessions      →  Break work into parallel, isolated sessions
   ↓
 [implement]   →  Hooks enforce quality in real time
   ↓
/wire-check    →  Verify everything is connected before commit
/review        →  Staff-engineer-level code review (sub-agent)
/review-codex  →  Adversarial security review from a different AI model
   ↓
 [PR + CI]     →  Automated quality gates block bad merges
```

### Why This Order Matters

**`/plan` → `/plan-review`** — Forces thinking before writing. AI makes writing so cheap that planning feels like friction. It's not. The 2 minutes you spend reviewing a plan saves the 45-minute "oh wait, that already existed" rewrite.

**`/sessions`** — Decomposes a PRD into self-contained prompts for parallel Claude Code sessions, each in its own git worktree. You get velocity from parallelism and quality from isolation. Auto-generates a review session when there are 2+ implementation sessions.

**`/review`** — Runs a staff engineer sub-agent that reviews your diff adversarially. Dead code, duplication, scope creep, test quality, security — 10-point checklist with BLOCK/WARN/NIT severity.

**`/review-codex`** — Dispatches your diff to a different AI model (OpenAI) for a cold-start security review. Different model = different blind spots. Claude then evaluates each finding (AGREE/DISAGREE/CONTEXT) so you get a cross-validated verdict.

## What's in This Repo

### [`FRAMEWORK.md`](FRAMEWORK.md) — The Master Execution Plan

A 1,400-line document containing **6 self-contained phases**, each designed to be executed in a single Claude Code session. Work through them sequentially.

| Phase | What It Does | Time |
|-------|-------------|------|
| **1. Foundation** | Install Biome, Knip, Lefthook, Claude Code hooks, all slash commands | 1-2 hrs |
| **2. CI/CD + Strictness** | GitHub Actions quality gates, TypeScript strict mode | 1-2 hrs |
| **3. Mutation Testing** | Stryker integration — prove your tests work | 2-3 hrs |
| **4. Template Repository** | Reusable project template with full framework | 2-3 hrs |
| **5. Cleanup** | Remove dead code, audit tests, consolidate duplication | 1-2 weeks |
| **6. Workflow Mastery** | Daily/weekly/monthly rituals, advanced patterns | Ongoing |

### [`template/`](template/) — Starter Template

Ready-to-use project template with everything pre-configured:

- **Static analysis:** Biome, Knip, jscpd, madge, TypeScript strict mode
- **Testing:** Vitest + coverage thresholds, Stryker mutation testing
- **Enforcement:** Lefthook pre-commit hooks, Claude Code hooks, GitHub Actions CI
- **AI configs:** `CLAUDE.md`, `.cursorrules`, `CONVENTIONS.md`
- **8 slash commands:** `/plan`, `/plan-review`, `/sessions`, `/wire-check`, `/health-check`, `/audit-tests`, `/review`, `/review-codex`

## The Toolchain

| When | Tool | What It Does |
|------|------|-------------|
| **Before writing** | [Pharaoh](https://pharaoh.so) + `pharaoh:plan` | Query codebase graph — blast radius, function search, module coupling. Plan with wiring declarations. |
| **Before writing** | `/plan` + `/plan-review` | Force planning and deep review before implementation (local fallback without Pharaoh) |
| **Before writing** | `/sessions` or `pharaoh:sessions` | Decompose work into parallel, isolated Claude Code sessions |
| **Every edit** | [Biome](https://biomejs.dev) | Lint + format. Fast, opinionated, replaces ESLint + Prettier |
| **Every edit** | Claude Code hooks | Typecheck + lint after each file change. Instant feedback loop |
| **Before commit** | `/wire-check` | Verify all exports are wired, all files are imported |
| **Before commit** | [Lefthook](https://github.com/evilmartians/lefthook) / [Husky](https://typicode.github.io/husky/) | Git hooks: typecheck, lint, knip |
| **Before PR** | `/review` | Staff engineer sub-agent reviews the diff adversarially |
| **Before PR** | `/review-codex` | Cross-model security review (requires `OPENAI_API_KEY`) |
| **CI** | GitHub Actions | Full gate: typecheck + lint + test + knip + orphan check |
| **CI** | [Stryker](https://stryker-mutator.io) | Mutation testing — proves tests actually catch bugs |
| **Periodic** | `/health-check` | Codebase health audit |
| **Periodic** | `/audit-tests` | Classify tests by value — find ceremony vs. real protection |

## Slash Commands

| Command | What It Does | When to Use |
|---------|-------------|-------------|
| `/plan` | Explore codebase, estimate LOC, get approval | Before any implementation |
| `/plan-review` | Deep plan review — architecture, wiring, tests, security | Before implementing non-trivial changes |
| `/sessions` | Generate parallel session prompts from a PRD | When work can be parallelized across worktrees |
| `/wire-check` | Pre-commit quality gate | Before every commit |
| `/health-check` | Full codebase audit | Weekly or monthly |
| `/audit-tests` | Test value classification | When test suite feels bloated |
| `/review` | Adversarial code review by sub-agent | Before opening a PR |
| `/review-codex` | Cross-model security review | Before merging security-sensitive changes |

## Key Concepts

### The Quality Ratchet

Every metric moves in one direction. You never lower a threshold.

| Metric | Direction | Cadence |
|--------|-----------|---------|
| Knip issues | toward 0 | Weekly |
| jscpd duplication % | down | Monthly (-0.5%) |
| Coverage % | up | Monthly (+2%) |
| Mutation score | up | Monthly (+2%) |
| Source LOC | stable or down | Monthly |

### The Oracle Gap

Coverage tells you what code *ran*. Mutation score tells you what code was *verified*. The gap between them is the **oracle gap** — tests that exercise code but don't actually assert anything meaningful. This framework closes that gap with Stryker.

### Claude Code Hooks

Three hooks that run automatically:

- **Post-edit hook** — Typechecks and lints after every file edit. Claude gets instant feedback and fixes issues before moving on.
- **Pre-write hook** — Blocks writes to `.env`, lock files, `dist/`, and other sensitive files.
- **Stop hook** — Runs typecheck + lint + knip + orphan check when Claude tries to finish. Broken code can't be marked "done."

### AI Agents Write Unwired Code

LLMs have a systematic failure mode: they write a function, export it, mark the task "done," but never wire it into the execution path. The orphan detection script catches this at three gates: Claude Code Stop hook, pre-commit, and CI.

### Cross-Model Review

A single AI model has consistent blind spots. `/review-codex` dispatches your diff to a different model for a cold-start security review, then Claude evaluates each finding. This cross-validation catches vulnerabilities that either model alone would miss.

### Session Parallelism

Instead of one long Claude Code session that degrades in quality over time, `/sessions` decomposes work into isolated sessions, each in its own git worktree. Benefits:
- **Context isolation** — each session has fresh context, no degradation
- **Parallel execution** — independent sessions run simultaneously
- **Atomic PRs** — each session produces one focused PR
- **Built-in review** — auto-generates a review session when there are 2+ implementation sessions

## Who This Is For

- Teams using **Claude Code** for daily development
- **TypeScript** projects (the configs are opinionated for this stack)
- Engineers who want to **move fast without accumulating hidden debt**
- Anyone who's noticed their AI-generated codebase growing faster than it should

## Getting Started

### Step 0: Install Pharaoh (recommended)

The slash commands in this framework handle enforcement and workflow. [Pharaoh](https://pharaoh.so) adds the intelligence layer - your AI agent queries a knowledge graph instead of reading files one at a time.

```bash
# Install the GitHub App (maps all your org repos automatically)
# Visit: github.com/apps/pharaoh-so

# Or connect via MCP:
npx @pharaoh-so/mcp

# Install the skill library (23 development workflow skills):
npx @pharaoh-so/mcp --install-skills
```

Once installed, the `pharaoh:*` skills are graph-powered equivalents of this framework's slash commands - same workflows, but backed by architectural data instead of static analysis. See the [skill mapping](#pharaoh-skill-mapping) below.

### Step 1: Set up the framework

**Option A: Start from scratch with the template**
```bash
# Use the GitHub template, then:
git clone <your-new-repo>
cd <your-new-repo>
bash scripts/bootstrap.sh
# Fill in CLAUDE.md [FILL IN] sections
```

**Option B: Add to an existing project**
1. Open [`FRAMEWORK.md`](FRAMEWORK.md)
2. Start at Phase 1
3. Paste each phase into Claude Code as a task
4. Work through sequentially — each phase builds on the last

## Pharaoh Skill Mapping

This framework's slash commands run locally with static analysis tools. Pharaoh's `pharaoh:*` skills do the same workflows but backed by a knowledge graph - they see the full architecture, not just the files on disk.

If you have Pharaoh installed (Step 0), use the graph-powered versions. If not, the local commands still work.

| Framework Command | Pharaoh Skill | What Changes |
|-------------------|--------------|--------------|
| `/plan` | `pharaoh:plan` | Adds graph recon (blast radius, existing functions, module coupling) before planning. Wiring declarations prevent dead exports. |
| `/plan-review` | `pharaoh:plan` (Phase 5) | Adversarial review checks reachability and coupling against graph data, not just code reading. |
| `/health-check` | `pharaoh:health` | Replaces knip/jscpd/madge with graph queries: dead code, duplication, test coverage, regression risk, spec drift. Grades A-F. |
| `/audit-tests` | `pharaoh:audit-tests` | Same test classification, plus graph-powered identification of high-risk untested functions. |
| `/review` | `pharaoh:review` | Adds blast radius, wiring verification, regression risk scoring, and spec alignment to the review checklist. |
| `/review-codex` | `pharaoh:review-codex` | Same cross-model security review pattern. |
| `/wire-check` | `pharaoh:wiring` | Graph-based reachability check instead of script-based orphan detection. Catches more cases (re-exports, barrel files, dynamic imports). |
| `/sessions` | `pharaoh:sessions` | Same session decomposition, with graph context for each session's scope. |
| — | `pharaoh:debt` | New: categorized tech debt report (DELETE, CONSOLIDATE, DOCUMENT, STABILIZE, TEST). |
| — | `pharaoh:onboard` | New: rapid codebase orientation from graph data. |
| — | `pharaoh:refactor` | New: blast-radius-aware refactoring. Maps every caller before changing anything. |

The local slash commands and Pharaoh skills are complementary, not exclusive. The enforcement layer (Biome, Knip, Lefthook, CI gates) still runs regardless. Pharaoh adds the intelligence layer that prevents problems before the enforcement layer has to catch them.

**Install Pharaoh:** [github.com/apps/pharaoh-so](https://github.com/apps/pharaoh-so) | [Docs](https://pharaoh.so/docs) | [Multi-agent playbooks](https://pharaoh.so/docs/guides/multi-agent-teams)

## Multi-Agent Teams

For teams running multiple AI agents, Pharaoh ships pre-built playbook configurations:

- **Code Review Team** - coordinator + architecture analyst + code reviewer (all read-only)
- **Feature Development** - planner + coder + tester with TDD and architectural awareness
- **Tech Debt Sprint** - auditor grades codebase A-F, fixer implements prioritized cleanup
- **Codebase Onboarding** - single agent for rapid architecture orientation

Each playbook includes agent configs, workspace files, and setup instructions. Try them on a real repo: [Pharaoh-so/taskflow-api](https://github.com/Pharaoh-so/taskflow-api).

Full playbook docs: [pharaoh.so/docs/guides/multi-agent-teams](https://pharaoh.so/docs/guides/multi-agent-teams)

## FAQ

**Does this work with Cursor / Copilot / other AI tools?**
The framework doc and toolchain work with anything. The Claude Code hooks and slash commands are Claude Code-specific, but the principles and CONVENTIONS.md apply universally.

**Is this overkill for a small project?**
Phase 1 (Biome + hooks + slash commands) takes an hour and pays for itself immediately. You can stop there. Phases 2-6 are for projects that will live longer than a weekend.

**Won't the hooks slow Claude down?**
Typechecking adds ~2-5 seconds per edit. This catches errors while Claude still has context to fix them, instead of letting them compound into a broken codebase.

**Why cross-model review?**
Same reason you don't let the author review their own code. `/review` catches structural issues with a sub-agent. `/review-codex` dispatches to a completely different AI model for security review. Different architecture = different blind spots.

**Why mutation testing? Isn't coverage enough?**
Coverage measures what code ran. A test that calls a function and asserts nothing gives you coverage but catches zero bugs. Mutation testing modifies your source and checks if tests notice. It's the difference between "the test ran" and "the test works."

**What about `/sessions`? When do I use it?**
When you have a PRD, design doc, or task list that involves 3+ files across multiple modules. `/sessions` breaks it into self-contained prompts that run in parallel worktrees. Each session gets fresh context and produces an atomic PR. The auto-generated review session checks everything against the original plan.

## License

MIT — use it, fork it, adapt it.

## Credits

Built by [Dan Greer](https://github.com/0xUXDesign), battle-tested on a team shipping production code daily with Claude Code.

If this saves you time, a star helps others find it.
