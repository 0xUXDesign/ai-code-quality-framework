# Project Template — AI Code Quality Framework

Production-quality AI-generated code from day one. Clone this template and start shipping.

> Part of the [AI Code Quality Framework](https://github.com/0xUXDesign/ai-code-quality-framework). See [FRAMEWORK.md](https://github.com/0xUXDesign/ai-code-quality-framework/blob/main/FRAMEWORK.md) for the full execution plan.

## What's Included

### Static Analysis
- **Biome** — linter + formatter. `noUnusedImports` and `noUnusedVariables` are errors. `noExplicitAny` and `noNonNullAssertion` are warnings.
- **Knip** — dead code detection (unused exports, files, dependencies)
- **jscpd** — copy-paste detection
- **madge** — circular dependency detection
- **TypeScript** — strict mode with `noImplicitReturns`, `noFallthroughCasesInSwitch`, `allowUnreachableCode: false`

### Testing
- **Vitest** — test runner with coverage thresholds
- **Stryker** — mutation testing (incremental mode for fast feedback)

### Enforcement
- **Lefthook** — pre-commit hooks (typecheck + lint + knip)
- **Claude Code hooks** — typecheck on every edit, block writes to sensitive files, stop-check before finishing
- **GitHub Actions CI** — blocking quality gate (typecheck, lint, knip, duplication, circular deps, tests)
- **Branch ruleset** — CI must pass before merge (configure manually, see below)

### AI Tool Configs
- **CLAUDE.md** — instructions for Claude Code
- **.cursorrules** — instructions for Cursor
- **CONVENTIONS.md** — single source of truth referenced by both
- **8 slash commands** — full development lifecycle (see below)

## Getting Started

### From GitHub
1. Click **"Use this template"** on the GitHub repo page
2. Name your new repository
3. Clone and run setup:

```bash
git clone <your-new-repo>
cd <your-new-repo>
bash scripts/bootstrap.sh
```

### Manual Setup
```bash
pnpm install
npx lefthook install
pnpm run quality  # verify everything works
```

### After Cloning

1. **Update `CLAUDE.md`** — fill in the `[FILL IN]` sections with your project's architecture, entry points, patterns, and known debt
2. **Update `knip.json`** — set `entry` to your actual entry points
3. **Update `package.json`** — change name, description, and add your dependencies
4. **Set coverage thresholds** — run `pnpm run test:coverage`, then set thresholds in `vitest.config.ts` at current minus 5%
5. **Configure branch ruleset** on GitHub (see below)
6. **For `/review-codex`** — set `OPENAI_API_KEY` in your shell profile (optional but recommended)

## Branch Ruleset Setup

Go to your repo's Settings > Rules > Rulesets > New ruleset > New branch ruleset:

1. Name: `main protection`
2. Target branches: Add target > Include default branch
3. Branch rules — enable:
   - **Require a pull request before merging** (1 approval)
   - **Require status checks to pass** > Add checks > `quality`
   - **Block force pushes**
4. Save

## The Development Lifecycle

Every slash command maps to a step in the lifecycle:

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

## Scripts

| Script | Purpose |
|---|---|
| `pnpm run typecheck` | TypeScript type checking (zero errors required) |
| `pnpm run lint` | Biome linting (zero errors required) |
| `pnpm run lint:fix` | Auto-fix lint issues |
| `pnpm run test` | Run tests |
| `pnpm run test:coverage` | Run tests with coverage report |
| `pnpm run knip` | Dead code analysis |
| `pnpm run duplication` | Copy-paste detection |
| `pnpm run circular` | Circular dependency detection |
| `pnpm run quality` | Full quality suite (all of the above) |
| `pnpm run mutate` | Full mutation testing run |
| `pnpm run mutate:incremental` | Incremental mutation testing (fast) |
| `pnpm run mutate:module -- 'src/path/**'` | Mutation testing for one module |

## Slash Commands (Claude Code)

| Command | What It Does | When to Use |
|---|---|---|
| `/plan` | Explore codebase, estimate LOC, get approval | Before any implementation |
| `/plan-review` | Deep plan review — architecture, wiring, tests, security | Before implementing non-trivial changes |
| `/sessions` | Generate parallel session prompts from a PRD | When work spans 3+ files across modules |
| `/wire-check` | Pre-commit quality gate | Before every commit |
| `/health-check` | Full codebase audit | Weekly or monthly |
| `/audit-tests` | Test value classification | When test suite feels bloated |
| `/review` | Adversarial code review by sub-agent | Before opening a PR |
| `/review-codex` | Cross-model security review (requires `OPENAI_API_KEY`) | Before merging security-sensitive changes |

## Quality Ratchet

Track these metrics monthly. They should only move in one direction:

| Metric | Direction |
|---|---|
| Knip issues | toward 0 |
| jscpd duplication % | down |
| Coverage % | up (+2%/month) |
| Mutation score | up (+2%/month) |
| Source LOC | stable or down |
| Circular deps | toward 0 |
