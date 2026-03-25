# AI Codebase Boilerplate — Master Execution Plan

**Scope:** Any React / React Native / TypeScript project
**Thesis:** Deterministic enforcement + disciplined workflow = production-quality AI-generated code at high velocity.

This document contains **6 self-contained PRD-Lites**, each executable in a single Claude Code session. Work through them sequentially. Each leaves the codebase strictly better than before.

**Prerequisites for all phases:**
- Claude Code installed and authenticated
- Project repo cloned locally
- Node.js 20+ installed

---

## Phase 0: Codebase Intelligence (recommended)

**Goal:** Install Pharaoh so your AI agent queries a knowledge graph instead of reading files one at a time. This is optional but makes every subsequent phase more effective - the agent sees blast radius, existing functions, and module coupling before making decisions.

**Time estimate:** 5 minutes
**Risk level:** None - read-only, no code changes

### Steps

#### 0.1 — Install the GitHub App

Visit [github.com/apps/pharaoh-so](https://github.com/apps/pharaoh-so) and install on your org. Pharaoh auto-maps all repos on install and refreshes on every push.

Alternatively, connect via MCP:
```bash
npx @pharaoh-so/mcp
```

#### 0.2 — Install the skill library

```bash
npx @pharaoh-so/mcp --install-skills
```

This installs 23 development workflow skills. The `pharaoh:*` skills are graph-powered equivalents of the slash commands installed in Phase 1. See the [skill mapping](https://github.com/0xUXDesign/ai-codebase-boilerplate#pharaoh-skill-mapping) in the README.

#### 0.3 — Verify

Ask your AI tool:
```
Show me the architecture of this repo
```

If Pharaoh is connected, it will query `get_codebase_map` and return the full module landscape in ~2 seconds.

---

## Phase 1: Foundation — Toolchain + Enforcement Layer

**Goal:** Install the core static analysis toolchain and Claude Code hooks so that type errors, unused imports, formatting issues, and writes to sensitive files are mechanically blocked during AI generation.

**Time estimate:** 1-2 hours
**Risk level:** Low — additive only, no code changes to existing source

### File Scope

**ALLOWED (create/modify):**
```
biome.json
knip.json
lefthook.yml
.claude/settings.json
.claude/commands/plan.md
.claude/commands/plan-review.md
.claude/commands/sessions.md
.claude/commands/wire-check.md
.claude/commands/health-check.md
.claude/commands/audit-tests.md
.claude/commands/review.md
.claude/commands/review-codex.md
CLAUDE.md
package.json (devDependencies + scripts only)
scripts/hooks/post-edit-check.sh
scripts/hooks/pre-commit-check.sh
scripts/hooks/stop-check.sh
scripts/hooks/block-sensitive.sh
```

**FORBIDDEN (everything else, especially):**
```
src/**  — no source code changes
tests/** or __tests__/** — no test changes
tsconfig.json — do not modify yet (Phase 2)
.env* — never touch
```

### Steps

#### 1.1 — Install devDependencies

```bash
# npm/yarn users: substitute your package manager
pnpm add -D @biomejs/biome knip lefthook jscpd madge
```

Do NOT install Stryker yet (Phase 3).

#### 1.2 — Configure Biome

Create `biome.json` at repo root:

```json
{
  "$schema": "https://biomejs.dev/schemas/2.0.0/schema.json",
  "organizeImports": {
    "enabled": true
  },
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true,
      "correctness": {
        "noUnusedImports": "error",
        "noUnusedVariables": "error",
        "noUnusedFunctionParameters": "warn",
        "useExhaustiveDependencies": "warn"
      },
      "suspicious": {
        "noExplicitAny": "warn",
        "noDoubleEquals": "error"
      },
      "complexity": {
        "noExcessiveCognitiveComplexity": {
          "level": "warn",
          "options": { "maxAllowedComplexity": 25 }
        }
      },
      "style": {
        "noNonNullAssertion": "warn",
        "useConst": "error"
      }
    }
  },
  "formatter": {
    "enabled": true,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 100
  },
  "files": {
    "ignore": ["node_modules", "dist", "build", "coverage", ".next", "*.min.js", "android", "ios"]
  }
}
```

**NOTE:** Run `npx biome check src/` first as a DRY RUN to see current violations. Do not auto-fix yet — just record the count. If violations are overwhelming (500+), start with `"recommended": false` and enable rules incrementally. If manageable (<100), proceed with recommended.

**React Native note:** You may also want to ignore `android/` and `ios/` native directories.

#### 1.3 — Configure Knip

Create `knip.json` at repo root. Adjust entry/project paths to match your project's structure:

```json
{
  "$schema": "https://unpkg.com/knip@latest/schema.json",
  "entry": [
    "src/index.ts",
    "src/App.tsx",
    "src/main.tsx"
  ],
  "project": ["src/**/*.{ts,tsx}"],
  "ignore": ["**/*.test.ts", "**/*.test.tsx", "**/*.spec.ts", "**/__tests__/**"],
  "ignoreDependencies": []
}
```

**CRITICAL:** Run `npx knip` and review output BEFORE adding to any automated checks. Knip may flag entry points it doesn't know about (navigation setup, screen components registered dynamically, deep link handlers). Add these to the `entry` array until false positives are eliminated. This calibration step is non-negotiable — skipping it will cause false alarms that erode trust in the tool.

**Common React Native entry points to add:**
- `index.js` or `index.ts` (app entry)
- Navigation configuration files
- Screen components if registered dynamically

**Common React (web) entry points to add:**
- `src/main.tsx` or `src/index.tsx`
- Route configuration files
- Lazy-loaded page components

#### 1.4 — Create hook scripts

Create `scripts/hooks/` directory with these scripts. Each must be executable (`chmod +x`).

**`scripts/hooks/post-edit-check.sh`** — runs after every file edit:
```bash
#!/bin/bash
# Post-edit: typecheck + lint changed file
# Exit 0 = pass, Exit 2 = fail (feedback to Claude)

FILE="$CLAUDE_FILE_PATH"

# Only check TypeScript files
if [[ "$FILE" != *.ts && "$FILE" != *.tsx ]]; then
  exit 0
fi

# Typecheck (fast, no emit)
npx tsc --noEmit 2>&1
TSC_EXIT=$?

if [ $TSC_EXIT -ne 0 ]; then
  echo "TYPE ERROR: Fix type errors before continuing." >&2
  exit 2
fi

# Lint changed file only (fast)
npx biome check "$FILE" 2>&1
BIOME_EXIT=$?

if [ $BIOME_EXIT -ne 0 ]; then
  echo "LINT ERROR: Fix lint errors before continuing." >&2
  exit 2
fi

exit 0
```

**`scripts/hooks/block-sensitive.sh`** — blocks writes to protected files:
```bash
#!/bin/bash
# Pre-write: block sensitive file modifications
# Exit 2 = blocked

FILE="$CLAUDE_FILE_PATH"

BLOCKED_PATTERNS=(
  ".env"
  ".env.*"
  "package-lock.json"
  "pnpm-lock.yaml"
  "yarn.lock"
  ".git/"
  "dist/"
  "build/"
  "node_modules/"
  "ios/Pods/"
  "android/app/build/"
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if [[ "$FILE" == *"$pattern"* ]]; then
    echo "BLOCKED: Cannot modify $FILE — protected file. Request manual changes from the team." >&2
    exit 2
  fi
done

exit 0
```

**`scripts/hooks/stop-check.sh`** — runs when Claude finishes:
```bash
#!/bin/bash
# Stop hook: verify codebase is clean before completing
# Exit 2 = re-inject error, Claude must fix

# Typecheck
npx tsc --noEmit 2>&1
if [ $? -ne 0 ]; then
  echo "STOP BLOCKED: Type errors remain. Fix them before finishing." >&2
  exit 2
fi

# Lint
npx biome check src/ 2>&1
if [ $? -ne 0 ]; then
  echo "STOP BLOCKED: Lint errors remain. Fix them before finishing." >&2
  exit 2
fi

# Dead code (knip)
npx knip 2>&1
if [ $? -ne 0 ]; then
  echo "STOP BLOCKED: Unused exports detected by knip. Remove or unexport them." >&2
  exit 2
fi

# Orphan check (unwired exports)
if [ -f "scripts/check-orphaned-exports.sh" ]; then
  bash scripts/check-orphaned-exports.sh 2>&1
  if [ $? -ne 0 ]; then
    echo "STOP BLOCKED: Orphaned exports detected. Wire them up or delete them." >&2
    exit 2
  fi
fi

exit 0
```

Make all executable:
```bash
chmod +x scripts/hooks/*.sh
```

#### 1.5 — Configure Claude Code hooks

Create `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|Create",
        "command": "bash scripts/hooks/post-edit-check.sh",
        "timeout": 30000
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Create",
        "command": "bash scripts/hooks/block-sensitive.sh",
        "timeout": 5000
      }
    ],
    "Stop": [
      {
        "command": "bash scripts/hooks/stop-check.sh",
        "timeout": 60000
      }
    ]
  }
}
```

**NOTE:** Hook configuration format may vary by Claude Code version. Check `claude --help hooks` or the docs at code.claude.com/docs/en/hooks-guide for current syntax. The three hook types and exit code protocol (0=pass, 2=block+feedback) are stable.

#### 1.6 — Configure pre-commit hooks

You have two solid options for git hooks. Pick one:

**Option A: Lefthook** (lightweight, no Node dependency for the hook runner itself)

Create `lefthook.yml` at repo root:

```yaml
pre-commit:
  parallel: true
  commands:
    typecheck:
      run: npx tsc --noEmit
    lint:
      run: npx biome check {staged_files}
      glob: "*.{ts,tsx,js,jsx}"
    knip:
      run: npx knip --no-exit-code
      # no-exit-code initially — advisory only until calibrated
```

Install:
```bash
npx lefthook install
```

**Option B: Husky** (battle-tested, widely adopted, simple shell scripts)

```bash
pnpm add -D husky
npx husky init
```

Create `.husky/pre-commit`:
```bash
#!/bin/bash
pnpm run typecheck
pnpm run lint
npx knip --no-exit-code
```

Both work well. Lefthook has parallel execution built-in. Husky is more widely recognized. DanBot (a production codebase using this framework) runs Husky with 8 sequential pre-commit checks including custom domain validators.

#### 1.7 — Add scripts

Add to `package.json` scripts (merge with existing, do not replace):

```json
{
  "scripts": {
    "build": "tsc",
    "lint": "biome check src/",
    "lint:fix": "biome check --write src/",
    "typecheck": "tsc --noEmit",
    "knip": "knip",
    "duplication": "jscpd src/ --threshold 5",
    "circular": "madge --circular --extensions ts,tsx src/",
    "check:orphans": "bash scripts/check-orphaned-exports.sh",
    "quality": "pnpm run build && pnpm run lint && pnpm run knip && pnpm run check:orphans && pnpm run duplication && pnpm run circular && pnpm test"
  }
}
```

**NOTE:** The quality chain starts with `build` (full TypeScript compilation), not just `typecheck`. This catches errors that `--noEmit` misses (declaration file generation, output path issues). Adjust `pnpm` to your package manager (`npm`, `yarn`) if needed.

Both Pharaoh and DanBot (production codebases built with this framework) use pnpm. The framework examples use `pnpm` by default — substitute your package manager as needed.

#### 1.8 — Write CLAUDE.md

Create `CLAUDE.md` at repo root. Keep under 150 lines:

```markdown
# CLAUDE.md — [PROJECT NAME]

## MANDATORY RULES

These are non-negotiable. Hooks enforce most of them automatically.

### Before Writing Code
- SEARCH the codebase for existing solutions before proposing anything new
- REUSE or EXTEND existing code — do not duplicate
- Present a plan with estimated net LOC change. WAIT for approval on non-trivial changes
- Target ZERO or NEGATIVE net LOC change

### While Writing Code
- NO unused imports (enforced by Biome)
- NO `any` types without explicit justification
- NO stubs, placeholder functions, or TODO implementations
- NO new files unless necessary — extend existing files first
- CLEAN UP adjacent code when touching a file (dead code, unused vars)
- EVERY export must be imported somewhere — no orphan exports

### Before Committing
- `pnpm run typecheck` — zero errors (enforced by hooks)
- `pnpm run lint` — zero errors (enforced by hooks)
- `pnpm run knip` — review any new findings
- Tests pass for changed modules

### Test Rules
- Do NOT auto-generate tests unless explicitly asked
- Test BEHAVIOR, not implementation
- Use hardcoded expected values, never computed ones
- One integration test > ten unit tests
- Every test must be able to FAIL — if you can't describe what makes it fail, delete it

### Commit Messages
- Use conventional commits: feat|fix|refactor|chore|docs|test(scope): description
- Scope = module name (e.g., auth, navigation, api)

## Architecture

[FILL IN: Brief description of your app's architecture — screens, navigation structure, state management, API layer. Keep to 20 lines max.]

## Common Patterns

[FILL IN: 3-5 patterns used in this codebase — how to add a new screen, how to add an API call, how to add a new component, etc. Keep to 30 lines max.]

## Known Debt

[FILL IN: Current technical debt items. Update as debt is created or resolved.]
```

**IMPORTANT:** The `[FILL IN]` sections must be completed by examining the actual codebase. Do not leave them as placeholders — CLAUDE.md with placeholders is worse than no CLAUDE.md because it signals that instructions don't matter.

#### 1.9 — Create Orphan Detection Script

Create `scripts/check-orphaned-exports.sh` — a lightweight script that finds exported functions with no callers:

```bash
#!/bin/bash
# Orphan Export Detector
# Finds exported functions that are never imported elsewhere.
# Usage: bash scripts/check-orphaned-exports.sh

set -euo pipefail

SRC_DIR="${1:-src}"
WARNING_THRESHOLD="${2:-3}"
orphan_count=0
orphans=""

# Find all exported functions
while IFS= read -r file; do
  while IFS= read -r match; do
    func_name=$(echo "$match" | grep -oP '(?<=function )\w+')
    [ -z "$func_name" ] && continue

    # Skip common entry points
    case "$func_name" in
      handler|config|main|default) continue ;;
    esac

    # Search for imports of this function across the codebase
    import_count=$(grep -rl "\b${func_name}\b" "$SRC_DIR" --include="*.ts" --include="*.tsx" | grep -v "$(basename "$file")" | wc -l || true)

    if [ "$import_count" -eq 0 ]; then
      orphans="${orphans}  ${file}: ${func_name}()\n"
      orphan_count=$((orphan_count + 1))
    fi
  done < <(grep -nE '^export (async )?function ' "$file" 2>/dev/null || true)
done < <(find "$SRC_DIR" -name "*.ts" -not -name "*.test.ts" -not -name "*.d.ts" -not -path "*/node_modules/*" 2>/dev/null)

if [ "$orphan_count" -gt 0 ]; then
  echo "⚠️  ${orphan_count} potentially orphaned exports:"
  echo -e "$orphans"
fi

if [ "$orphan_count" -gt "$WARNING_THRESHOLD" ]; then
  echo "❌ THRESHOLD EXCEEDED: ${orphan_count} orphans (max: ${WARNING_THRESHOLD})"
  echo "Wire up or delete unused exports before continuing."
  exit 1
fi

echo "✅ Orphan check passed (${orphan_count}/${WARNING_THRESHOLD} threshold)"
exit 0
```

Make executable: `chmod +x scripts/check-orphaned-exports.sh`

**NOTE:** This is a lightweight bash implementation suitable for most projects. For larger codebases (500+ files), consider a TypeScript version using AST parsing for accuracy. DanBot's production implementation (`scripts/check-orphaned-exports.ts`) adds support for dynamic imports, internal same-file callers, allowlists, and critical/warning severity tiers.

**Why this matters — AI agents write unwired code:**

LLM coding agents have a systematic failure mode: they satisfy the immediate instruction ("write function X") and register "done" without verifying the function is reachable from any entry point. Writing code *feels* like shipping the feature. The wiring step — importing it, registering it in a router, calling it from the right handler — is a separate cognitive step that gets dropped, especially in long sessions where context drifts.

This isn't a bug you can prompt away. It's a structural property of how LLMs optimize for task completion. The only reliable fix is a deterministic gate: the orphan check runs at the Stop hook (blocks Claude Code from finishing), pre-commit (blocks git commit), and CI (blocks merge). Three gates, zero escape paths.

#### 1.10 — Create Slash Commands

Create `.claude/commands/` directory.

**`.claude/commands/plan.md`**
```markdown
---
description: Plan before coding — explore, estimate, get approval
---

Before implementing anything:

1. **Search** the codebase for existing code related to this task
2. **Identify** what can be reused, extended, or must be new
3. **Estimate** net LOC change (target: zero or negative)
4. **Flag** any dead code or duplication you see in the area
5. **Present** the plan with file scope (which files you'll touch)
6. **WAIT** for approval before writing any code

Format your plan as:
- Task: [what we're doing]
- Reuse: [existing code to extend]
- New: [new code needed, with justification]
- Remove: [dead code to clean up]
- Net LOC: [estimated change]
- Files: [list of files to touch]
- Risk: [what could go wrong]
```

**`.claude/commands/wire-check.md`**
```markdown
---
description: Pre-commit quality gate — verify everything is wired up
---

Run these checks and report results:

1. `pnpm run typecheck` — zero errors
2. `pnpm run lint` — zero errors
3. `pnpm run knip` — report any NEW unused exports/files/dependencies
4. Check for unused imports in changed files
5. Check that every new export is imported somewhere
6. Check that every new file is imported by at least one other file
7. List all TODO/FIXME/HACK comments in changed files
8. Report net LOC change: `git diff --stat`

Present results as PASS/FAIL for each check. Do not commit if any FAIL.
```

**`.claude/commands/health-check.md`**
```markdown
---
description: Periodic codebase audit — find accumulated problems
---

Run a full codebase health audit:

1. `npx knip` — dead exports, unused files, unused dependencies
2. `npx jscpd src/ --threshold 5` — code duplication report
3. `npx madge --circular --extensions ts,tsx src/` — circular dependencies
4. Find all TODO/FIXME/HACK/DEBT comments: `grep -rn "TODO\|FIXME\|HACK\|DEBT" src/`
5. Find files over 500 lines: `find src/ -name "*.ts" -o -name "*.tsx" | xargs wc -l | awk '$1 > 500'`
6. Find functions over 50 lines (approximate): look for long function bodies
7. Count total source LOC: `find src/ -name "*.ts" -o -name "*.tsx" | xargs wc -l`
8. Count total test LOC: `find . -name "*.test.ts" -o -name "*.test.tsx" | xargs wc -l`

Present as a health scorecard with trends if previous data exists.
```

**`.claude/commands/audit-tests.md`**
```markdown
---
description: Classify tests by value — find ceremony vs. real protection
---

For the specified directory (or all tests if none specified):

1. List every test file and test count
2. Classify each test as:
   - **CRITICAL** — tests a core business behavior, uses hardcoded expected values
   - **USEFUL** — tests a real edge case or integration boundary
   - **REDUNDANT** — duplicates coverage of another test
   - **TAUTOLOGICAL** — asserts only `.toBeDefined()`, `.toBeTruthy()`, or computes expected values from the same code it's testing
   - **ORPHANED** — tests code that no longer exists
   - **OVER-MOCKED** — mocks so much the test is self-referential
3. Recommend: KEEP / CONSOLIDATE / DELETE for each
4. REPORT ONLY — do NOT modify or delete any tests
```

**`.claude/commands/sessions.md`**
```markdown
---
description: Generate implementation session prompts from a PRD or research doc
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion
argument: doc-path
---

Generate self-contained, copy-paste-ready prompts for parallel Claude Code sessions
that implement a PRD or research document.

## Input Resolution

1. If `$ARGUMENTS` is provided and non-empty, use it as the doc path
2. If no argument: run `ls -t docs/plans/*.md docs/sessions/*.md 2>/dev/null | head -1`
3. If nothing found, ask the user which file to use
4. Print the resolved doc path prominently so the user can confirm
5. Read the full document content

## Analysis

- Identify logical work units — each = one session = one worktree = one PR
- Assess complexity (simple/medium/complex)
- Map dependency graph between sessions

## Output

1. Summary table: sessions, parallelization, dependencies
2. For each session: a fenced code block with a complete, self-contained prompt
   (setup, scope, key files, implementation steps, testing, exit criteria, boundaries)
3. If 2+ implementation sessions: auto-generate a review session that checks all
   work against the original plan

## Rules

- Plan file must be committed before generating session prompts
- Each prompt must be self-contained (works in a fresh Claude Code window)
- Worktree names: kebab-case (e.g., `fix/billing-session-persistence`)
- Verify file existence before listing in prompts
- Explicitly tell each session what NOT to touch
```

See `template/.claude/commands/sessions.md` for the full, detailed version.

**`.claude/commands/review.md`**
```markdown
---
description: Pre-PR code review by a staff engineer sub-agent
context: fork
agent: Explore
---

You are a senior staff engineer reviewing a PR before merge. You are adversarial —
your job is to find problems, not confirm the code works.

## Branch Awareness

Print branch name and directory at the top of output. If on main with empty diff, STOP.

## Review Checklist

For each changed file, evaluate:

1. Dead code — unused imports, exports, variables, functions
2. Duplication — search codebase for existing code to reuse
3. Scope creep — changes unrelated to the branch intent
4. Test quality — hardcoded expected values, meaningful assertions
5. Error handling — no swallowed errors, useful messages
6. Types — no `any`, no unsafe type assertions
7. Complexity — no functions over 50 lines
8. Naming — communicates intent
9. Architecture — fits existing patterns
10. Security — auth gaps, injection, data exposure, IDOR, secrets in code, CSRF

## Output

File:line findings with BLOCK/WARN/NIT severity and concrete fix suggestions.
End with: APPROVE, APPROVE WITH WARNINGS, or REQUEST CHANGES.
```

See `template/.claude/commands/review.md` for the full, detailed version.

**`.claude/commands/review-codex.md`**
```markdown
---
description: Adversarial security review via OpenAI model — second opinion from a different AI
---

Dispatches your diff to a different AI model (OpenAI) for a cold-start security review.
Different model = different blind spots. Claude then evaluates each finding.

## Prerequisites

- `OPENAI_API_KEY` environment variable must be set
- Branch must have changes vs main

## Process

1. Gather context: git diff, codebase recon, security rules from CLAUDE.md
2. Construct a security-focused prompt with architecture context + review checklist
3. Dispatch to OpenAI via Chat Completions API
4. Present findings with Claude's independent assessment (AGREE/DISAGREE/CONTEXT)
5. Combined verdict: action items ordered by severity + recommendation
```

See `template/.claude/commands/review-codex.md` for the full, detailed version.

### Acceptance Criteria

- [ ] `npx biome check src/` runs without crashing (violations OK for now)
- [ ] `npx knip` runs and produces a report (findings OK for now)
- [ ] `npx jscpd src/` runs and produces a duplication report
- [ ] `npx madge --circular --extensions ts,tsx src/` runs
- [ ] Claude Code hooks are configured and active (verify with a test edit)
- [ ] `npx lefthook install` completes, pre-commit hook fires on `git commit`
- [ ] CLAUDE.md exists with all `[FILL IN]` sections completed
- [ ] All 8 slash commands exist and are recognized by Claude Code (`/plan`, `/plan-review`, `/sessions`, `/wire-check`, `/health-check`, `/audit-tests`, `/review`, `/review-codex`)
- [ ] `pnpm run check:orphans` runs and produces a report
- [ ] `pnpm run quality` runs all checks in sequence
- [ ] No source code in `src/` was modified

---

## Phase 2: CI/CD + Prevention Gates

**Goal:** Set up GitHub Actions CI as the merge-blocking final gate. Tighten TypeScript config. Lock down branch protection.

**Time estimate:** 1-2 hours
**Risk level:** Low-Medium — tsconfig changes may surface existing type issues
**Depends on:** Phase 1 complete

### File Scope

**ALLOWED:**
```
.github/workflows/ci.yml
.github/workflows/knip.yml (optional, separate workflow)
tsconfig.json
package.json (scripts only)
src/**/*.{ts,tsx} — ONLY to fix type errors caused by tsconfig tightening
```

**FORBIDDEN:**
```
biome.json — already configured
.claude/ — already configured
tests/** or __tests__/** — no test changes
```

### Steps

#### 2.1 — Tighten tsconfig.json

Add these flags (merge with existing, do not replace):

```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "allowUnreachableCode": false,
    "allowUnusedLabels": false,
    "forceConsistentCasingInFileNames": true
  }
}
```

**STRATEGY FOR EXISTING ERRORS:** Run `npx tsc --noEmit` after each flag addition. If a single flag produces 50+ errors, add it with a `// @ts-expect-error` suppression file or enable it per-file with `// @ts-check`. Do NOT skip the flag — suppress and track. The goal is zero errors on `tsc --noEmit` at all times.

**Aspirational flags (add later, not day-one):**
- `noUncheckedIndexedAccess` — extremely valuable but produces hundreds of errors in existing codebases. Add in Phase 5 cleanup after the codebase is stabilized.
- `verbatimModuleSyntax` — requires all imports to use explicit `type` annotations. Can conflict with some bundler/framework setups. Add when your toolchain fully supports it.
- `exactOptionalPropertyTypes` — the strictest flag. Defer until Phase 5.

Both Pharaoh and DanBot (production codebases built with this framework) run `strict: true` with the core flags above but do NOT use `noUncheckedIndexedAccess` or `verbatimModuleSyntax`. Ship with the core flags first; add the aspirational ones when you're ready to handle the error volume.

**React Native note:** Some RN libraries have loose types. You may need to add type declarations or use `skipLibCheck: true` temporarily.

#### 2.2 — Create CI workflow

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  quality:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4

      # --- pnpm setup (use this if your project uses pnpm) ---
      - uses: pnpm/action-setup@v4
        with:
          version: 9

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'    # or 'npm' / 'yarn'

      - run: pnpm install  # or: npm ci

      # --- Quality chain (matches local `pnpm run quality`) ---
      - name: Build
        run: pnpm run build

      - name: Lint
        run: pnpm run lint

      - name: Dead code
        run: pnpm run knip

      - name: Orphan check
        run: pnpm run check:orphans

      - name: Duplication
        run: pnpm run duplication

      - name: Circular dependencies
        run: pnpm run circular

      - name: Tests
        run: pnpm test
        # TODO Phase 3: add coverage thresholds

      - name: Net LOC tracking
        if: github.event_name == 'pull_request'
        run: |
          echo "## LOC Change" >> $GITHUB_STEP_SUMMARY
          git diff --stat origin/main...HEAD >> $GITHUB_STEP_SUMMARY
```

**npm users:** Remove the `pnpm/action-setup` step, change `cache: 'pnpm'` to `cache: 'npm'`, and use `npm ci` / `npm run` / `npm test`.

**React Native note:** If you use Jest for testing (common in RN), the test command may differ. Adjust accordingly.

#### 2.3 — Configure branch protection

This is a manual GitHub step. Document it here to execute:

1. Go to repo Settings → Branches → Add rule
2. Branch name pattern: `main`
3. Enable:
   - Require pull request reviews before merging (1 reviewer)
   - Require status checks to pass: `quality`
   - Require branches to be up to date before merging
   - Do not allow bypassing the above settings
4. Save

### Acceptance Criteria

- [ ] `npx tsc --noEmit` passes with zero errors (suppressions OK if documented)
- [ ] `.github/workflows/ci.yml` exists and runs on PR
- [ ] CI runs all 7 checks: typecheck, lint, knip, orphan check, jscpd, madge, tests
- [ ] Branch protection requires CI to pass before merge
- [ ] CI fails correctly when a deliberate error is introduced (test it)
- [ ] Net LOC tracking appears in PR summary

---

## Phase 3: Testing Infrastructure

**Goal:** Install Stryker for mutation testing, establish the testing protocol, and add coverage thresholds. Set up the "trust but verify" testing workflow.

**Time estimate:** 2-3 hours
**Risk level:** Low — additive, does not modify existing tests
**Depends on:** Phase 2 complete

### File Scope

**ALLOWED:**
```
stryker.config.mjs (or .json)
vitest.config.ts OR jest.config.js (modify coverage thresholds only)
package.json (devDependencies + scripts only)
.github/workflows/ci.yml (add mutation step)
```

**FORBIDDEN:**
```
src/** — no source changes
tests/** or __tests__/** — do NOT modify or delete existing tests yet (Phase 5)
```

### Steps

#### 3.1 — Install Stryker

For **Vitest** projects:
```bash
pnpm add -D @stryker-mutator/core @stryker-mutator/typescript-checker @stryker-mutator/vitest-runner
```

For **Jest** projects (common in React Native):
```bash
pnpm add -D @stryker-mutator/core @stryker-mutator/typescript-checker @stryker-mutator/jest-runner
```

#### 3.2 — Configure Stryker

Create `stryker.config.mjs`:

```javascript
/** @type {import('@stryker-mutator/api/core').PartialStrykerOptions} */
export default {
  testRunner: 'vitest', // or 'jest' for React Native
  checkers: ['typescript'],
  tsconfigFile: 'tsconfig.json',
  mutate: [
    'src/**/*.ts',
    'src/**/*.tsx',
    '!src/**/*.test.ts',
    '!src/**/*.test.tsx',
    '!src/**/*.spec.ts',
    '!src/**/*.d.ts',
    '!src/**/index.ts',        // barrel files
    '!src/**/types.ts',        // type-only files
    '!src/**/constants.ts',    // constants
  ],
  incremental: true,
  incrementalFile: '.stryker-incremental.json',
  thresholds: {
    high: 80,
    low: 60,
    break: 50   // CI fails below 50% mutation score
  },
  reporters: ['html', 'clear-text', 'progress'],
  concurrency: 4,
  timeoutMS: 30000,
};
```

Add `.stryker-incremental.json` to `.gitignore`.
Add `reports/mutation/` to `.gitignore`.

#### 3.3 — Add scripts

Add to `package.json`:

```json
{
  "scripts": {
    "mutate": "stryker run",
    "mutate:incremental": "stryker run --incremental",
    "mutate:module": "stryker run --mutate"
  }
}
```

Usage:
- `pnpm run mutate:incremental` — daily, fast (only changed code)
- `pnpm run mutate` — weekly, full run
- `pnpm run mutate:module -- 'src/components/**/*.tsx'` — audit one module

#### 3.4 — Set coverage thresholds

**For Vitest** - in `vitest.config.ts`:

```typescript
export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json-summary', 'html'],
      thresholds: {
        // Start at current coverage level, ratchet up over time
        // Run `npx vitest run --coverage` first to see current numbers
        lines: 0,      // FILL IN: current coverage - 5%
        branches: 0,   // FILL IN: current coverage - 5%
        functions: 0,  // FILL IN: current coverage - 5%
        statements: 0, // FILL IN: current coverage - 5%
      },
    },
  },
});
```

**For Jest** - in `jest.config.js`:

```javascript
module.exports = {
  coverageThreshold: {
    global: {
      lines: 0,      // FILL IN: current coverage - 5%
      branches: 0,   // FILL IN: current coverage - 5%
      functions: 0,  // FILL IN: current coverage - 5%
      statements: 0, // FILL IN: current coverage - 5%
    },
  },
};
```

**IMPORTANT:** Set thresholds at current coverage minus 5% initially. This prevents regressions without requiring immediate improvement. Ratchet up 2-3% per month.

#### 3.5 — Run initial Stryker baseline

```bash
npx stryker run 2>&1 | tee reports/stryker-baseline.txt
```

Record the mutation score. This is your "before" measurement. Commit the report.

Expected: If test suite is AI-generated, mutation score will likely be 30-50% despite high line coverage. This gap IS the oracle gap — tests execute code but don't verify behavior.

#### 3.6 — Add mutation testing to CI (weekly)

Add to `.github/workflows/ci.yml` or create a separate weekly workflow:

```yaml
  mutation:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # needed for incremental mode
      - uses: pnpm/action-setup@v4
        with:
          version: 9
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'
      - run: pnpm install
      - name: Mutation testing (incremental)
        run: pnpm run mutate:incremental
      - name: Upload mutation report
        uses: actions/upload-artifact@v4
        with:
          name: mutation-report
          path: reports/mutation/
          retention-days: 14
```

### Acceptance Criteria

- [ ] `pnpm run mutate:incremental` runs and produces a mutation score
- [ ] Baseline mutation score is recorded and committed
- [ ] Coverage thresholds are set at current coverage minus 5%
- [ ] `pnpm test -- --coverage` fails if coverage drops below threshold
- [ ] Stryker `incremental` mode works (second run is faster than first)
- [ ] CI includes mutation testing on main branch pushes
- [ ] No existing tests were modified or deleted

---

## Phase 4: Template Repository

**Goal:** Create a GitHub Template Repository that any new project can clone, inheriting the full quality framework from day one.

**Time estimate:** 2-3 hours
**Risk level:** None — separate repository, does not affect current project
**Depends on:** Phases 1-3 complete and validated

### File Scope

**This creates a NEW repository. All files are new.**

```
project-template/
├── .claude/
│   ├── settings.json          # Claude Code hooks
│   └── commands/
│       ├── plan.md
│       ├── wire-check.md
│       ├── health-check.md
│       └── audit-tests.md
├── .github/
│   └── workflows/
│       └── ci.yml
├── scripts/
│   └── hooks/
│       ├── post-edit-check.sh
│       ├── pre-commit-check.sh
│       ├── stop-check.sh
│       └── block-sensitive.sh
├── src/
│   └── index.ts               # minimal entry point
├── __tests__/
│   └── index.test.ts          # example test
├── biome.json
├── knip.json
├── lefthook.yml
├── stryker.config.mjs
├── tsconfig.json
├── vitest.config.ts           # or jest.config.js
├── package.json
├── CLAUDE.md
├── .cursorrules               # for Cursor users
├── CONVENTIONS.md             # single source of truth
├── .gitignore
└── README.md
```

### Steps

#### 4.1 — Create the repository

```bash
mkdir project-template && cd project-template
git init
pnpm init
```

#### 4.2 — Copy and generalize configs from current project

Copy all config files (Phases 1-3), but:
- Remove project-specific entries from `knip.json` (entry points)
- Remove project-specific patterns from `CLAUDE.md`
- Make `CLAUDE.md` a template with clear `[FILL IN]` sections

#### 4.3 — Create CONVENTIONS.md

This is the single source of truth referenced by CLAUDE.md, .cursorrules, and any other AI tool config:

```markdown
# Development Conventions

## TypeScript
- Strict mode always. No `any` without justification.
- Prefer interfaces over type aliases for object shapes.
- Use `unknown` over `any` for unknown types.
- Exhaustive switch statements with `never` default.

## File Organization
- One concern per file. If a file exceeds 300 lines, split it.
- Barrel files (index.ts) for public API only.
- Co-locate tests: `foo.ts` → `foo.test.ts` in same directory (or `__tests__/foo.test.ts`).

## Naming
- camelCase: variables, functions, methods
- PascalCase: types, interfaces, classes, components
- SCREAMING_SNAKE: constants, env vars
- kebab-case: file names (or PascalCase for components)

## Error Handling
- Never swallow errors silently.
- Use typed error classes for domain errors.
- Log errors with context (what was being attempted, with what inputs).

## Dependencies
- Justify every new dependency. Prefer stdlib/existing deps.
- Check bundle size impact before adding.
- Pin major versions.

## Git
- Conventional commits: feat|fix|refactor|chore|docs|test(scope): description
- One concern per commit. Atomic changes.
- Feature branches off main. PRs required.
```

#### 4.4 — Create .cursorrules

```
See CONVENTIONS.md for all coding standards.
Always search the codebase before proposing new code.
Target zero or negative net LOC change.
Do not auto-generate tests unless asked.
Do not add dependencies without justification.
```

#### 4.5 — Template the CLAUDE.md

```markdown
# CLAUDE.md — [PROJECT NAME]

## MANDATORY RULES

[Same mandatory rules as Phase 1, but with [FILL IN] for project-specific sections]

## Architecture

[FILL IN: 10-20 line description of this project's architecture]

## Entry Points

[FILL IN: List all entry points for Knip/dependency analysis]

## Common Patterns

[FILL IN: 3-5 patterns specific to this project]

## Known Debt

[FILL IN: Current technical debt — update as debt is created or resolved]
```

#### 4.6 — Add bootstrap script

Create `scripts/bootstrap.sh`:

```bash
#!/bin/bash
# Run after cloning from template
echo "Setting up development environment..."

pnpm install
npx lefthook install  # or: npx husky init

echo "Setup complete. Run 'pnpm run quality' to verify."
echo ""
echo "Don't forget to:"
echo "  1. Update CLAUDE.md with project-specific details"
echo "  2. Update knip.json entry points"
echo "  3. Set up GitHub branch protection rules"
```

#### 4.7 — Mark as template

1. Push to GitHub as `your-org/project-template`
2. Go to Settings → check "Template repository"
3. New projects: click "Use this template" → full framework inherited

### Acceptance Criteria

- [ ] Template repo exists on GitHub and is marked as template
- [ ] `pnpm install && pnpm run quality` passes in a fresh clone
- [ ] Lefthook installs and pre-commit hooks work
- [ ] Claude Code hooks are active when opening with Claude Code
- [ ] CI workflow runs on push
- [ ] CLAUDE.md, .cursorrules, and CONVENTIONS.md all reference each other
- [ ] bootstrap.sh runs without errors
- [ ] README documents the framework and how to use the template

---

## Phase 5: Codebase Cleanup

**Goal:** Systematically reduce codebase bloat without losing any existing functionality. Each sub-phase is independently safe — stop at any point and the codebase is strictly better.

**Time estimate:** 8-12 hours spread over 1-2 weeks
**Risk level:** Medium — modifying existing code. Characterization tests provide safety net.
**Depends on:** Phase 1-2 complete (enforcement layer prevents re-introduction of bloat)

### File Scope

**ALLOWED:**
```
src/** — removals and refactoring only
tests/** or __tests__/** — test modifications/deletions ONLY after Stryker analysis
package.json — dependency removal only
knip.json — entry point adjustments
```

**FORBIDDEN:**
```
biome.json — do not change rules during cleanup
.claude/ — do not change hooks during cleanup
.github/ — do not change CI during cleanup
tsconfig.json — do not change strictness during cleanup
```

### Sub-Phase 5A: Safe Removals (2-3 hours)

**Rule: only remove things that are provably unused.**

```bash
# Step 1: Remove unused dependencies
npx knip --dependencies
# Review output. For each flagged dependency:
#   - Is it used via dynamic require/import? (check)
#   - Is it a CLI tool used in scripts? (check package.json scripts)
#   - If genuinely unused → pnpm remove <package>
# Run tests after each removal batch.

# Step 2: Remove unused files
npx knip --files
# Review output. For each flagged file:
#   - Is it an entry point Knip doesn't know? → add to knip.json
#   - Is it used via dynamic import? → check
#   - If genuinely unused → delete
# Run tests after each removal batch.

# Step 3: Auto-fix lint issues
npx biome check --write src/
# This removes unused imports and fixes formatting.
# Run tests after.

# Step 4: Record progress
npx knip --reporter json > reports/knip-post-phase5a.json
git diff --stat HEAD  # should show net negative LOC
```

### Sub-Phase 5B: Dead Export Pruning (3-5 hours, multiple sessions)

**Rule: batch processing, tests after each batch.**

```bash
# Get the full list
npx knip --exports > reports/unused-exports.txt
```

For each batch of 10-20 unused exports:
1. Verify not used via dynamic access, reflection, or external consumers
2. Delete the export keyword and the function/type/variable if nothing else uses it
3. Run `pnpm test` and `npx tsc --noEmit`
4. If green, continue. If red, revert that specific removal and investigate.

**Expect cascading effects:** removing one export may make its imports unused, which may make their files unused. Run `npx knip` after each batch to catch cascades.

### Sub-Phase 5C: Test Audit (4-6 hours over a week)

**Rule: analyze FIRST, then get approval, then modify. Never delete tests without Stryker data.**

```bash
# Step 1: Run Stryker on one module at a time
npx stryker run --mutate 'src/components/**/*.tsx'
npx stryker run --mutate 'src/screens/**/*.tsx'
npx stryker run --mutate 'src/api/**/*.ts'
# etc.

# Step 2: For each module, identify:
# - Tests with 0% mutation kill rate → candidates for deletion
# - Tests that are tautological (assertions that can't fail)
# - Tests that are redundant (same mutations killed by another test)
# - Tests that are orphaned (testing deleted code)

# Step 3: For tests marked for deletion:
# - Run the test suite WITHOUT the test to verify nothing depends on it
# - Delete in batches of 5-10
# - Re-run Stryker to verify mutation score is maintained or improved

# Step 4: For tests marked for consolidation:
# - Merge 3-5 unit tests into 1 integration test
# - The integration test should cover the same mutations
# - Verify with Stryker
```

Target: reduce test count by 30-50% while maintaining or improving mutation score.

### Sub-Phase 5D: Duplication Consolidation (ongoing, 1-2 hours/week)

```bash
# Get duplication report with locations
npx jscpd src/ --threshold 3 --reporters json --output reports/

# For each duplicate cluster:
# 1. Identify the "canonical" version (most complete/correct)
# 2. Extract into a shared utility function or component
# 3. Replace all duplicates with calls to the utility
# 4. Run tests after each consolidation
```

### Sub-Phase 5E: Lock It Down

After cleanup phases complete:

```bash
# Tighten Knip to zero tolerance
# In CI, change knip step to:
npx knip --max-issues 0

# Tighten jscpd threshold
# Calculate current duplication percentage, set threshold 1% below

# Record final metrics
echo "=== POST-CLEANUP METRICS ===" > reports/cleanup-final.txt
echo "Source LOC:" >> reports/cleanup-final.txt
find src/ -name "*.ts" -o -name "*.tsx" | grep -v test | xargs wc -l >> reports/cleanup-final.txt
echo "Test LOC:" >> reports/cleanup-final.txt
find . -name "*.test.ts" -o -name "*.test.tsx" | xargs wc -l >> reports/cleanup-final.txt
echo "Dependencies:" >> reports/cleanup-final.txt
cat package.json | npx json dependencies | wc -l >> reports/cleanup-final.txt
echo "Mutation score:" >> reports/cleanup-final.txt
# run stryker and record
```

### Acceptance Criteria

- [ ] All unused dependencies removed
- [ ] All provably unused files deleted
- [ ] All provably unused exports removed
- [ ] Biome auto-fix applied (unused imports removed)
- [ ] Test count reduced by 20%+ while mutation score maintained
- [ ] jscpd duplication percentage decreased
- [ ] Zero circular dependencies (or documented exceptions)
- [ ] Knip runs clean with `--max-issues 0` in CI
- [ ] All existing functionality verified via test suite
- [ ] Before/after metrics committed to `reports/`

---

## Phase 6: Workflow Mastery

**Goal:** Establish the full development lifecycle, daily/weekly/monthly rhythms, and advanced Claude Code patterns that sustain quality over time.

**Time estimate:** Ongoing — 30 min/week + 2-3 hours/month
**Risk level:** None — process changes only
**Depends on:** Phases 1-5 complete

### The Development Lifecycle

This is the complete lifecycle for any non-trivial task. Not every task needs every step — use judgment — but the full sequence is:

```
/plan              →  Explore codebase, estimate LOC, get approval
/plan-review       →  Deep review of the plan before writing code
/sessions          →  Break work into parallel, isolated sessions (for multi-file tasks)
   ↓
 [implement]       →  Hooks enforce quality in real time
   ↓
/wire-check        →  Verify everything is connected before commit
/review            →  Staff-engineer-level code review (sub-agent)
/review-codex      →  Adversarial security review from a different AI model
   ↓
 [PR + CI]         →  Automated quality gates block bad merges
```

**Why each step matters:**

- **`/plan`** — Search before writing. AI makes writing so cheap that planning feels like friction. The 2 minutes spent in `/plan` saves the 45-minute "that already existed" rewrite.
- **`/plan-review`** — Deep evaluation of the plan: architecture, wiring, test gaps, performance. For non-trivial changes, use BIG CHANGE mode (full interactive review). For small changes, SMALL CHANGE mode (quick pass through sections 2-4).
- **`/sessions`** — For tasks touching 3+ files across multiple modules. Decomposes a PRD into self-contained session prompts, each running in its own git worktree. Parallel sessions = velocity. Isolated context = quality. Auto-generates a review session when there are 2+ implementation sessions.
- **`/wire-check`** — The "did I leave anything undone?" check. Every new export imported, every file reachable, zero type errors, zero lint errors.
- **`/review`** — Runs a staff engineer sub-agent that reviews your diff adversarially. 10-point checklist including dead code, duplication, test quality, security. BLOCK/WARN/NIT severity with concrete fix suggestions.
- **`/review-codex`** — Dispatches the diff to a different AI model for cold-start security review. Different model = different blind spots. Claude evaluates each finding (AGREE/DISAGREE/CONTEXT). Requires `OPENAI_API_KEY`.

### Daily Workflow

#### For small tasks (single file, straightforward changes):

```
1. Start Claude Code session
2. /plan [task description]     ← Search + plan before code
3. Review plan, approve
4. Let Claude implement          ← Hooks enforce quality in real time
5. /wire-check                   ← Verify everything is connected
6. /review                       ← Sub-agent reviews the diff
7. Commit, open PR
8. /clear between tasks          ← Prevent context degradation
```

#### For large tasks (multi-file, multi-module):

```
1. Write or identify the PRD / task document
2. /plan-review [PRD]            ← Deep plan review before any code
3. Resolve all issues from the review
4. /sessions [PRD]               ← Generate parallel session prompts
5. Open one Claude Code window per session, each in its own worktree
6. Each session: implement → /wire-check → commit → PR
7. Review session: verify all work against original plan
8. /review on each PR            ← Staff engineer review
9. /review-codex on security-sensitive PRs  ← Cross-model security review
10. Merge
```

### Weekly Ritual (30 minutes, e.g. Friday)

```
1. pnpm run mutate:incremental   ← Find surviving mutants
2. Fix 3-5 weak tests            ← Improve assertions, not coverage
3. Delete tests that kill 0 mutants
4. Review oracle gap trend       ← coverage minus mutation score
5. Quick /health-check           ← Catch any drift
```

### Monthly Ritual (2-3 hours, e.g. first Monday)

```
1. pnpm run quality              ← Full quality suite
2. npx knip                      ← Remove any accumulated dead code
3. npx knip --dependencies       ← Remove unused packages
4. Review jscpd report           ← Consolidate new duplications
5. Clean up stale feature flags
6. Update CLAUDE.md Known Debt section
7. Tighten coverage thresholds by 2%
8. Tighten jscpd threshold by 0.5%
```

### Advanced Patterns

**Session Parallelism with `/sessions`:**
Instead of one long Claude Code session that degrades in quality over time, `/sessions` decomposes work into isolated sessions, each in its own git worktree. Benefits:
- **Context isolation** — each session has fresh context, no degradation
- **Parallel execution** — independent sessions run simultaneously
- **Atomic PRs** — each session produces one focused PR
- **Built-in review** — auto-generated review session checks everything against the plan

```bash
# /sessions generates prompts. You open separate terminals:
git worktree add ../project-fix-billing fix/billing
git worktree add ../project-fix-display fix/display
# Paste session prompts into separate Claude Code instances
# Each runs independently, produces a PR
```

**Cross-Model Review with `/review-codex`:**
A single AI has consistent blind spots. `/review-codex` sends your diff to a completely different model (OpenAI) for cold-start security review. Claude then evaluates each finding independently. This catches vulnerabilities that either model alone would miss. Set up:
```bash
export OPENAI_API_KEY=sk-...  # add to shell profile
# Then just run /review-codex from any feature branch
```

**Document & Clear:**
For long tasks, have Claude write progress to `docs/SESSION.md`, then `/clear` and start a fresh session reading the file. This prevents the context degradation that causes quality to drop in long sessions. Delete `SESSION.md` after task completion.

**Builder-Validator Pattern:**
For critical features, use two Claude Code sessions:
1. **Builder** implements the feature
2. **Validator** (fresh context) runs `/review` and `/review-codex`
Fresh context catches things the builder's context has normalized.

### Ratchet Schedule

Track these metrics monthly. They should only move in one direction:

| Metric | Direction | Cadence |
|--------|-----------|---------|
| Knip issues | toward 0 | Weekly |
| jscpd % | down | Monthly (-0.5%) |
| Coverage % | up | Monthly (+2%) |
| Mutation score | up | Monthly (+2%) |
| Source LOC | stable or down | Monthly |
| Test/Source ratio | toward 0.5-0.8 | Monthly |
| Dependencies count | stable or down | Monthly |
| Circular deps | toward 0 | Monthly |
| Files > 500 LOC | down | Monthly |

### Acceptance Criteria

- [ ] Full lifecycle attempted: /plan → /plan-review → /sessions → implement → /wire-check → /review → PR
- [ ] Daily workflow is habitual for small tasks (Plan → Implement → Wire-check → Review)
- [ ] `/sessions` used to parallelize at least one multi-file task
- [ ] `/review` produces APPROVE/WARN/REQUEST CHANGES verdicts before PRs
- [ ] `/review-codex` attempted on at least one security-sensitive change (requires `OPENAI_API_KEY`)
- [ ] Weekly ritual is calendared and happening
- [ ] Monthly ritual is calendared and happening
- [ ] Metrics are tracked and trending in the right direction

---

## Platform-Specific Notes

### React Native

- **Jest vs Vitest:** React Native projects typically use Jest. Adjust test runner configs accordingly.
- **Native directories:** Add `android/` and `ios/` to ignore patterns in biome.json and other tools.
- **Metro bundler:** Some dynamic imports for navigation may cause false positives in Knip.
- **Detox/E2E:** If using Detox for E2E tests, those don't integrate with Stryker. Focus mutation testing on unit/integration tests.

### React (Web)

- **Vite/Next.js:** Both work well with Vitest. Next.js may need additional entry points in knip.json for pages/app router.
- **Bundle analysis:** Consider adding `source-map-explorer` or `@next/bundle-analyzer` to the quality pipeline.
- **SSR code:** Server components/API routes are regular TypeScript and work with all tools.

### Monorepos

If using a monorepo (Turborepo, Nx, etc.):
- Configure Knip with workspaces support
- Set up CI to run quality checks per-package
- Consider a root-level quality script that aggregates results
