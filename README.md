# AI Code Quality Framework

**Production-quality AI-generated code without losing velocity.**

I manage a team of 15+ engineers building a product that processes $100M+ daily volume. We use Claude Code for nearly everything. Six months in, I noticed a pattern: AI coding tools are incredibly fast, but they silently accumulate debt that kills you later — unused imports, orphan exports, copy-pasted logic, tests that can't actually fail, and a codebase that grows 3x faster than it should.

The conventional wisdom is "AI code needs heavy human review." That's wrong. The real problem is that AI tools have no feedback loop. They write code, you accept it, and nobody checks whether it's actually wired up, actually tested, or actually necessary.

This framework fixes that by making quality **mechanical and automatic** — not aspirational.

## The Thesis

> Deterministic enforcement + disciplined workflow = production-quality AI-generated code at high velocity.

Instead of hoping Claude writes clean code, you make it impossible for Claude to produce dirty code. Hooks block bad output in real time. CI gates block bad merges. Mutation testing proves your tests actually work. Dead code detection ensures nothing accumulates.

The result: your AI-assisted codebase gets *cleaner* over time instead of rotting.

## What's in This Repo

### [`FRAMEWORK.md`](FRAMEWORK.md) — The Master Execution Plan

A 1,200-line document containing **6 self-contained phases**, each designed to be executed in a single Claude Code session. Work through them sequentially. Each leaves the codebase strictly better than before.

| Phase | What It Does | Time |
|-------|-------------|------|
| **1. Foundation** | Install Biome, Knip, Lefthook/Husky, Claude Code hooks | 1-2 hrs |
| **2. CI/CD + Strictness** | GitHub Actions quality gates, TypeScript strict mode | 1-2 hrs |
| **3. Mutation Testing** | Stryker integration — prove your tests work | 2-3 hrs |
| **4. Template Repository** | Reusable project template with full framework | 2-3 hrs |
| **5. Cleanup** | Remove dead code, audit tests, consolidate duplication | 1-2 weeks |
| **6. Workflow Mastery** | Daily/weekly/monthly rituals, advanced patterns | Ongoing |

Each phase is written as a **PRD-Lite** — a self-contained specification you can paste directly into Claude Code. It includes exact file scope (what Claude is allowed to touch and what's forbidden), step-by-step instructions, and acceptance criteria.

### [`template/`](template/) — Starter Template

A ready-to-use project template with everything pre-configured. Use GitHub's "Use this template" button or clone it directly.

Includes: Biome config, Knip config, Lefthook pre-commit hooks, Claude Code hooks (`.claude/settings.json`), Stryker config, Vitest with coverage thresholds, GitHub Actions CI, slash commands (`/plan`, `/wire-check`, `/health-check`, `/audit-tests`), and a `CLAUDE.md` with `[FILL IN]` sections for your project's specifics.

## The Toolchain

| Tool | Role | Why This One |
|------|------|-------------|
| [Biome](https://biomejs.dev) | Linter + formatter | Fast, opinionated, replaces ESLint + Prettier |
| [Knip](https://knip.dev) | Dead code detection | Finds unused exports, files, dependencies |
| [Lefthook](https://github.com/evilmartians/lefthook) or [Husky](https://typicode.github.io/husky/) | Git hooks | Lefthook: fast parallel execution. Husky: widely adopted, simple shell scripts |
| [Stryker](https://stryker-mutator.io) | Mutation testing | Proves tests actually catch bugs |
| [jscpd](https://github.com/kucherenko/jscpd) | Duplication detection | Finds copy-paste across codebase |
| [madge](https://github.com/pahen/madge) | Circular deps | Catches architectural tangles |
| Orphan detection | Unwired export detection | Catches functions with no callers |
| [Claude Code hooks](https://docs.anthropic.com) | Real-time enforcement | Typecheck on every edit, block sensitive files |

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

Coverage tells you what code *ran*. Mutation score tells you what code was *verified*. The gap between them is the **oracle gap** — tests that exercise code but don't actually assert anything meaningful. This framework closes that gap with Stryker.

### Claude Code Hooks

The secret weapon. Three hooks that run automatically:

- **Post-edit hook** — Typechecks and lints after every file edit. Claude gets instant feedback and fixes issues before moving on.
- **Pre-write hook** — Blocks writes to `.env`, lock files, `dist/`, and other sensitive files. Claude physically cannot modify them.
- **Stop hook** — Runs typecheck + lint + knip + orphan check when Claude tries to finish. If anything is broken, unused, or unwired, Claude is forced to fix it before completing.

This creates a closed feedback loop that doesn't exist in other AI coding setups.

### AI Agents Write Unwired Code

LLM coding agents have a systematic failure mode: they write a function, mark the task "done," but never wire it into the execution path. The function is exported but never imported or called. This isn't a prompting problem — it's structural to how LLMs optimize for task completion. The orphan detection script catches this at three gates: Claude Code Stop hook, pre-commit, and CI. Zero escape paths.

### Builder-Validator Pattern

For critical features, use two Claude Code sessions:
1. **Builder** implements the feature
2. **Validator** (fresh context) reviews with a security + quality checklist

Fresh context catches things the builder's context has normalized. This is the AI equivalent of code review.

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
4. Work through sequentially — each phase builds on the last

## Pair This With: Pharaoh

One thing this framework doesn't cover is **understanding what you're about to break before you break it.**

Static analysis catches syntax problems. CI catches test failures. But neither tells you "hey, if you rename this function, 14 callers across 6 modules will silently break" - and by the time you find out, you've burned an afternoon.

[Pharaoh](https://pharaoh.so) is an MCP server that maps your entire codebase and answers questions like:

- "What's the blast radius if I change this file?" (traces callers 5 hops deep)
- "Does a function like this already exist?" (prevents the duplication Knip catches later)
- "Which PRD specs don't have code yet?" (finds the gaps)
- "Do these two modules have a circular dependency?" (confirms what madge hints at)

I built this quality framework to keep AI-generated code clean. I use Pharaoh to keep myself from making expensive mistakes in the first place. Different problems, but they compound when used together.

**Install via GitHub App:** [github.com/apps/pharaoh-so/installations/new](https://github.com/apps/pharaoh-so/installations/new)

If you found this repo useful, use code **IMHOTEP** for 30% off.

## FAQ

**Does this work with Cursor / Copilot / other AI tools?**
The framework doc and toolchain work with anything. The Claude Code hooks (`.claude/settings.json`) and slash commands are Claude Code-specific, but the principles apply universally.

**Is this overkill for a small project?**
Phase 1 (Biome + hooks) takes an hour and pays for itself immediately. You can stop there. Phases 2-6 are for projects that will live longer than a weekend.

**Won't the hooks slow Claude down?**
Typechecking adds ~2-5 seconds per edit. This is a feature, not a bug — it catches errors while Claude still has context to fix them, instead of letting them compound into a broken codebase at the end.

**Why mutation testing? Isn't coverage enough?**
Coverage measures what code ran. A test that calls a function and asserts `true === true` gives you coverage but catches nothing. Mutation testing modifies your source code and checks if your tests notice. It's the difference between "the test ran" and "the test works."

## License

MIT — use it, fork it, adapt it.

## Credits

Built by [Dan Greer](https://github.com/0xUXDesign), battle-tested on a team shipping production code daily with Claude Code.

If this saves you time, a star helps others find it.
