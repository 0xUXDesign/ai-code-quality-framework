[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

# AI Code Quality Framework

**Production-quality AI-generated code without losing velocity.**

I manage a team of 15+ engineers building a product that processes $100M+ daily volume. We use Claude Code for nearly everything. Six months in, I noticed a pattern: AI coding tools are incredibly fast, but they silently accumulate debt that kills you later - unused imports, orphan exports, copy-pasted logic, tests that can't actually fail, and a codebase that grows 3x faster than it should.

The conventional wisdom is "AI code needs heavy human review." That's wrong. The real problem is that AI tools have no feedback loop. They write code, you accept it, and nobody checks whether it's actually wired up, actually tested, or actually necessary.

This framework fixes that by making quality **mechanical and automatic** - not aspirational.

## The Thesis

> Deterministic enforcement + disciplined workflow = production-quality AI-generated code at high velocity.

Instead of hoping Claude writes clean code, you make it impossible for Claude to produce dirty code. Hooks block bad output in real time. CI gates block bad merges. Mutation testing proves your tests actually work. Dead code detection ensures nothing accumulates.

The result: your AI-assisted codebase gets *cleaner* over time instead of rotting.

That handles half the problem. Hooks, CI, and mutation testing make sure your AI can't ship dirty code. But there's a second failure mode nobody talks about: your AI doesn't actually know your codebase. It can't check if a function already exists before writing a new one. It can't see that renaming a utility breaks 14 callers across 6 modules. It doesn't know which module owns what, or whether the thing it just built duplicates something three directories over. It just writes code and hopes.

Enforcement catches bad code. Intelligence prevents bad decisions. This framework handles enforcement. I use [Pharaoh](https://pharaoh.so) for the intelligence side - it turns your codebase into a knowledge graph your AI queries before touching anything. Different problems, same goal: AI code that actually gets better over time.

## What's in This Repo

### [`FRAMEWORK.md`](FRAMEWORK.md) - The Master Execution Plan

A 1,200-line document containing **6 self-contained phases**, each designed to be executed in a single Claude Code session. Work through them sequentially. Each leaves the codebase strictly better than before.

| Phase | What It Does | Time |
|-------|-------------|------|
| **1. Foundation** | Install Biome, Knip, Lefthook/Husky, Claude Code hooks | 1-2 hrs |
| **2. CI/CD + Strictness** | GitHub Actions quality gates, TypeScript strict mode | 1-2 hrs |
| **3. Mutation Testing** | Stryker integration - prove your tests work | 2-3 hrs |
| **4. Template Repository** | Reusable project template with full framework | 2-3 hrs |
| **5. Cleanup** | Remove dead code, audit tests, consolidate duplication | 1-2 weeks |
| **6. Workflow Mastery** | Daily/weekly/monthly rituals, advanced patterns | Ongoing |

Each phase is written as a **PRD-Lite** - a self-contained specification you can paste directly into Claude Code. It includes exact file scope (what Claude is allowed to touch and what's forbidden), step-by-step instructions, and acceptance criteria.

### [`template/`](template/) - Starter Template

A ready-to-use project template with everything pre-configured. Use GitHub's "Use this template" button or clone it directly.

Includes: Biome config, Knip config, Lefthook pre-commit hooks, Claude Code hooks (`.claude/settings.json`), Stryker config, Vitest with coverage thresholds, GitHub Actions CI, slash commands (`/plan`, `/plan-review`, `/wire-check`, `/health-check`, `/audit-tests`), and a `CLAUDE.md` with `[FILL IN]` sections for your project's specifics.

## The Toolchain

| When | Tool | What It Does |
|------|------|-------------|
| **Before writing** | [Pharaoh](https://pharaoh.so) | Query codebase graph - blast radius, function search, dead code, dependency tracing via MCP |
| **Every edit** | [Biome](https://biomejs.dev) | Lint + format. Fast, opinionated, replaces ESLint + Prettier |
| **Every edit** | [Claude Code hooks](https://docs.anthropic.com) | Typecheck + lint after each file change. Instant feedback loop |
| **Before commit** | [Lefthook](https://github.com/evilmartians/lefthook) or [Husky](https://typicode.github.io/husky/) | Git hooks. Lefthook: fast parallel execution. Husky: widely adopted |
| **Before commit** | [Knip](https://knip.dev) | Dead code detection - unused exports, files, dependencies |
| **Before commit** | Orphan detection | Catches exported functions with no callers |
| **CI** | GitHub Actions | Full gate: typecheck + lint + test + knip + orphan check |
| **CI** | [Stryker](https://stryker-mutator.io) | Mutation testing - proves tests actually catch bugs |
| **Periodic audit** | [jscpd](https://github.com/kucherenko/jscpd) | Copy-paste duplication detection |
| **Periodic audit** | [madge](https://github.com/pahen/madge) | Circular dependency detection |

## Key Concepts

### The Quality Ratchet

Every metric moves in one direction. You never lower a threshold.

| Metric | Direction | Cadence |
|--------|-----------|---------|
| Knip issues | → 0 | Weekly |
| jscpd duplication % | ↓ | Monthly (-0.5%) |
| Coverage % | ↑ | Monthly (+2%) |
| Mutation score | ↑ | Monthly (+2%) |
| Source LOC | ↓ or stable | Monthly |

### The Oracle Gap

Coverage tells you what code *ran*. Mutation score tells you what code was *verified*. The gap between them is the **oracle gap** - tests that exercise code but don't actually assert anything meaningful. This framework closes that gap with Stryker.

### Claude Code Hooks

The secret weapon. Three hooks that run automatically:

- **Post-edit hook** - Typechecks and lints after every file edit. Claude gets instant feedback and fixes issues before moving on.
- **Pre-write hook** - Blocks writes to `.env`, lock files, `dist/`, and other sensitive files. Claude physically cannot modify them.
- **Stop hook** - Runs typecheck + lint + knip + orphan check when Claude tries to finish. If anything is broken, unused, or unwired, Claude is forced to fix it before completing.

This creates a closed feedback loop that doesn't exist in other AI coding setups.

### AI Agents Write Unwired Code

LLM coding agents have a systematic failure mode: they write a function, export it, mark the task "done," but never wire it into the execution path. This isn't a prompting problem - it's structural to how LLMs optimize for task completion. Next session, different context, they build the same thing again. Over a few weeks your codebase is full of functions nobody calls.

The orphan detection script catches this at three gates: Claude Code Stop hook, pre-commit, and CI. Zero escape paths.

But you can also prevent it from the other direction. After implementing something, have your AI verify every new export is actually reachable from a production entry point. [Pharaoh's reachability checking](https://pharaoh.so) does this in one query - traces the call graph from entry points and flags anything disconnected. Detection at three gates plus prevention via graph means nothing slips through.

### Builder-Validator Pattern

For critical features, use two Claude Code sessions:
1. **Builder** implements the feature
2. **Validator** (fresh context) reviews with a security + quality checklist

Fresh context catches things the builder's context has normalized. This is the AI equivalent of code review.

### Plan Review

Before implementing any non-trivial change, run `/plan-review`. It enters plan mode - no code changes, just evaluation. Architecture check, wiring verification, test gap analysis, and structured decision points for every issue found.

Inspired by [Garry Tan's planning framework](https://www.youtube.com/watch?v=bMknfKXIFA8) for YC founders, adapted for AI-assisted development and trimmed to what actually matters in a code review. The core idea: force yourself to think before writing. AI makes this worse because writing is so cheap that planning feels like friction. It's not. The 2 minutes you spend in `/plan-review` saves the 45-minute "oh wait, that already existed" rewrite.

Works standalone with codebase search. Lights up with [Pharaoh](https://pharaoh.so) - blast radius checks, function search, reachability verification all happen automatically during the review.

## Who This Is For

- Teams using **Claude Code** or similar AI coding tools for daily development
- **React / React Native / TypeScript** projects (the configs are opinionated for this stack)
- Engineers who want to **move fast without accumulating hidden debt**
- Anyone who's noticed their AI-generated codebase growing faster than it should

## Getting Started

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
4. Work through sequentially - each phase builds on the last

## Add Codebase Intelligence

This framework makes your AI write clean code. [Pharaoh](https://pharaoh.so) makes your AI understand your codebase before it starts writing.

What it answers:

- "What's the blast radius if I change this file?" - traces callers across modules
- "Does a function like this already exist?" - prevents the duplication Knip catches later
- "Is this export reachable from any entry point?" - catches dead code before it lands
- "What breaks if I rename this?" - dependency tracing across repos

**Install via GitHub App:** [github.com/apps/pharaoh-so/installations/new](https://github.com/apps/pharaoh-so/installations/new)

If you found this repo useful, use code **IMHOTEP** for 30% off.

More on AI code quality at [pharaoh.so/blog](https://pharaoh.so/blog).

## FAQ

**Does this work with Cursor / Copilot / other AI tools?**
The framework doc and toolchain work with anything. The Claude Code hooks (`.claude/settings.json`) and slash commands are Claude Code-specific, but the principles apply universally.

**Is this overkill for a small project?**
Phase 1 (Biome + hooks) takes an hour and pays for itself immediately. You can stop there. Phases 2-6 are for projects that will live longer than a weekend.

**Won't the hooks slow Claude down?**
Typechecking adds ~2-5 seconds per edit. This is a feature, not a bug - it catches errors while Claude still has context to fix them, instead of letting them compound into a broken codebase at the end.

**Why mutation testing? Isn't coverage enough?**
Coverage measures what code ran. A test that calls a function and asserts `true === true` gives you coverage but catches nothing. Mutation testing modifies your source code and checks if your tests notice. It's the difference between "the test ran" and "the test works."

## License

MIT - use it, fork it, adapt it.

## Credits

Built by [Dan Greer](https://github.com/0xUXDesign), battle-tested on a team shipping production code daily with Claude Code.

If this saves you time, a star helps others find it.
