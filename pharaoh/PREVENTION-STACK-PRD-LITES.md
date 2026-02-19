# Prevention Stack: PRD-Lites for Near-100% Unwired Code Elimination

> Complements the v4 Unwired Code Plan (PR Guard). These sessions add three **prevention** layers to the existing **detection** layers. Detection catches problems at PR time. Prevention stops them from being created.

## Defense-in-Depth Architecture

| Layer | When | Mechanism | Bypassable? | Session |
|-------|------|-----------|-------------|---------|
| **Wiring Contract** | PRD-Lite design time | Human declares call sites before code exists | No (Dan writes it) | C |
| **Stop Hook** | End of CC session | `check_reachability` MCP call blocks session completion | No (deterministic hook) | A |
| **Knip** | Pre-commit + CI | Unused export detection (static analysis) | No (CI gate) | Already exists |
| **Knip × Pharaoh Reconciliation** | Phase 2D validation | Cross-reference two independent algorithms | Manual step | B |
| **PR Guard** | PR review | Graph + reference two-layer check | No (GitHub required check) | v4 Phase 3 |
| **Post-merge sweep** | After merge | Full reachability on default branch | Reactive | v4 Phase 5 |

---

## Session A: Claude Code Stop Hook for Reachability (30 min)

> **Depends on:** v4 Phase 2A complete (check_reachability MCP tool exists and working)
> **Repo:** Pharaoh (add hook), then DanBot (add hook)

### Goal

Add `check_reachability` as a deterministic Stop hook in Claude Code's `.claude/settings.json` so that CC **cannot finish a session** until every new exported function is reachable from a production entry point.

### Why This Matters

CLAUDE.md instructions are probabilistic — Claude Code can forget, skip, or deprioritize them under context pressure. Stop hooks are deterministic. CC literally cannot complete until the hook passes. This shifts the feedback loop from hours (PR review) to seconds (session completion), while the full implementation context is still loaded.

### File Scope

**ALLOWED:**
- `.claude/settings.json` (Pharaoh repo)
- `.claude/commands/check-wiring.md` (new — slash command for manual use)

**FORBIDDEN:** Everything else. Especially:
- `.claude/settings.json` enforcement layers (PostToolUse, PreToolUse) — do NOT modify existing hooks
- `lefthook.yml`, `.github/workflows/ci.yml`, `biome.json`

### Steps

1. **Read** `.claude/settings.json` to understand existing hook structure (PostToolUse for tsc + biome, PreToolUse blocks, existing Stop hooks if any).

2. **Add Stop hook** to the `hooks` section:
   ```json
   {
     "hooks": {
       "Stop": [
         {
           "matcher": ".*",
           "command": "pharaoh check-reachability --repo pharaoh --functions-in-diff"
         }
       ]
     }
   }
   ```

   The `--functions-in-diff` flag (to be added in a future Pharaoh CLI session if not already present) should:
   - Get the list of files changed in the current git diff (staged + unstaged)
   - Extract exported function names from those files
   - Run `check_reachability` for each
   - Exit 0 if all reachable, exit 1 if any unreachable (with details)

3. **If `--functions-in-diff` CLI flag doesn't exist yet**, use this interim approach instead:
   ```json
   {
     "hooks": {
       "Stop": [
         {
           "matcher": ".*",
           "command": "bash -c 'echo \"REMINDER: Run check_reachability on any new exported functions before finishing. Use /check-wiring command.\"'"
         }
       ]
     }
   }
   ```

   This is the soft version — a reminder, not a gate. Upgrade to the hard gate once `--functions-in-diff` exists.

4. **Create** `.claude/commands/check-wiring.md`:
   ```markdown
   # Check Wiring

   Run Pharaoh's check_reachability tool for all exported functions in files
   you've modified during this session.

   Steps:
   1. Run `git diff --name-only` to get changed files
   2. For each changed file, identify new or modified exported functions
   3. Call Pharaoh MCP `check_reachability` with those function names
   4. Report results — any unreachable functions must be wired before session ends

   If any function is unreachable:
   - Wire it into the appropriate call chain
   - Or remove the export if it's not needed
   - Or add it to .pharaoh.yml allowed_orphans with a justification
   ```

5. **Test** by creating a dummy exported function, running the hook, confirming it flags the function, then deleting the dummy.

### Acceptance Criteria

- [ ] Stop hook exists in `.claude/settings.json` and fires when CC session ends
- [ ] `/check-wiring` slash command exists and is usable mid-session
- [ ] Existing PostToolUse and PreToolUse hooks are UNTOUCHED
- [ ] No new dependencies added

### Notes

- The hard gate (exit 1 on unreachable) requires the Pharaoh CLI to support `--functions-in-diff`. If that doesn't exist after Phase 2A, the soft reminder is the right interim step.
- Repeat this session for DanBot repo once Pharaoh's `check_reachability` tool works against DanBot's graph.
- ⚠️ DEBT: The Stop hook calls Pharaoh MCP which requires the server to be running. If server is down, the hook will fail. Consider adding a timeout + graceful fallback.

---

## Session B: Knip × Pharaoh Reconciliation (1-2 hrs)

> **Depends on:** v4 Phase 2A-2C complete (check_reachability works, repo re-mapped with is_test)
> **Repo:** Pharaoh
> **When:** Runs as part of Phase 2D validation, not a separate deployment

### Goal

Create a reconciliation script that runs both Knip (static unused-export detection) and Pharaoh's `check_reachability` (graph-based reachability), diffs the results, and produces a categorized report showing where they agree and disagree. Agreement = near-100% confidence. Disagreement = investigation target.

### Why This Matters

Knip and Pharaoh use fundamentally different algorithms to answer the same question ("is this code used?"). Knip traces import/require statements statically. Pharaoh traces CALLS edges through a knowledge graph. Each has different blind spots. When both independently say "unused" — that's as close to certain as static analysis gets. When they disagree — that reveals data quality issues in one or both tools.

### File Scope

**ALLOWED:**
- `scripts/reconcile-knip-pharaoh.ts` (new)
- `tests/scripts/reconcile-knip-pharaoh.test.ts` (new)

**FORBIDDEN:** Everything else. This is a standalone analysis script, not a product feature.

### Steps

1. **Read** Knip's output format. Run `pnpm run knip --reporter json` (or `--reporter jsonExt`) to understand the JSON structure for unused exports.

2. **Read** Pharaoh's `get_unused_code` MCP tool output format. Understand the shape of unreachable function data.

3. **Create** `scripts/reconcile-knip-pharaoh.ts`:

   ```typescript
   // Pseudocode structure
   interface ReconciliationResult {
     both_flag: UnusedExport[];      // Both agree: near-100% dead code
     knip_only: UnusedExport[];      // Knip says unused, Pharaoh says reachable
     pharaoh_only: UnusedExport[];   // Pharaoh says unreachable, Knip says used
     both_clear: number;             // Count of exports both say are fine
   }
   ```

   Logic:
   - Run `pnpm run knip --reporter json` → parse unused exports
   - Query Pharaoh MCP `get_unused_code` → parse unreachable functions
   - Normalize both to a common key: `{filePath}:{exportName}`
   - Compute intersection (both_flag), Knip-only, Pharaoh-only
   - Output categorized report to stdout

4. **Interpret results:**
   - `both_flag` → **Delete candidates.** Both algorithms agree. Near-100% confidence.
   - `knip_only` → Pharaoh has a false CALLS edge (graph says reachable but Knip says no import exists). Investigate: is there a re-export, barrel file, or dynamic import Knip misses? Or is Pharaoh's Cartographer creating a spurious CALLS edge?
   - `pharaoh_only` → Pharaoh's graph is missing a CALLS edge that Knip's import tracing found. This is the more dangerous case — it means `check_reachability` has a false negative. Investigate: is it a callback, HOF, or config-driven call that the Cartographer doesn't trace?
   - `both_clear` → Healthy. No action needed.

5. **Add** `scripts/reconcile-knip-pharaoh.ts` to `package.json`:
   ```json
   "scripts": {
     "reconcile": "tsx scripts/reconcile-knip-pharaoh.ts"
   }
   ```

6. **Run** against Pharaoh repo. Document findings. This IS the Phase 2D validation — the results tell us the actual false positive/negative rate before we invest in PR Guard.

### Acceptance Criteria

- [ ] Script runs and produces categorized output for all four quadrants
- [ ] `both_flag` list can be reviewed for immediate cleanup
- [ ] `knip_only` and `pharaoh_only` lists reveal specific data quality issues
- [ ] Script exits 0 (it's analysis, not a gate — yet)
- [ ] No modifications to Knip config, Pharaoh source, or any other files

### Notes

- This script is diagnostic, not a product feature. It runs manually during validation.
- If the reconciliation shows <5% disagreement, we have strong evidence the two-layer approach works. If >10% disagreement, we need to improve Cartographer's CALLS edge accuracy before PR Guard will be reliable.
- Future: This could become a scheduled check that runs after every re-map and alerts on new disagreements.

---

## Session C: Wiring Contract in PRD-Lite Template (15 min)

> **Depends on:** Nothing. Can be done immediately.
> **Repo:** DanBot (where the dev-partnership skill lives) OR Claude.ai project skill

### Goal

Add a **Wiring Contract** section to the PRD-Lite template so that every PRD-Lite creating new exported functions must declare where they get called from BEFORE any code is written. This attacks root cause — unwired code exists because the call site was never specified.

### Why This Matters

Detection (PR Guard, Stop hooks, Knip) catches unwired code after it's written. The wiring contract prevents it from being unwired in the first place by making the call site an explicit design decision. Claude Code then has an unambiguous target: "wire processWidget into handleSlackEvent." No ambiguity, no hoping.

### File Scope

**ALLOWED:**
- `/mnt/skills/user/dev-partnership/SKILL.md` (if updating Claude.ai project skill)
- OR `docs/dev-partnership.md` / `.claude/CLAUDE.md` (if updating in-repo)

**FORBIDDEN:** Everything else.

### Changes

Add the following section to the PRD-Lite template, after the "File scope" requirement and before "Steps":

```markdown
### Wiring Contract (required for new exports)

Every PRD-Lite that creates new exported functions/classes/types must include a wiring contract table:

| New Export | Called From | Entry Point |
|------------|-------------|-------------|
| processWidget() | src/routes/slack.ts:handleSlackEvent | POST /api/slack |
| WidgetConfig (type) | src/tools/widget.ts:processWidget | (internal type) |
| initWidgetCache() | src/index.ts:startServer | Server startup |

Rules:
- If you can't fill in "Called From", the function probably shouldn't be exported
- Internal types referenced only within the same module can list "(internal type)"
- Barrel re-exports (index.ts) must show the FINAL consumer, not the barrel
- Event handlers must show the emitter: "eventBus.on('widget.created', processWidget)"
- Claude Code must wire each export to its declared call site before session ends
```

Update the PRD-Lite structure checklist to include wiring contract:

```markdown
Every PRD-Lite must include:
1. **Goal** — one sentence
2. **File scope** — ALLOWED (explicit list) + FORBIDDEN
3. **Wiring Contract** — table of new exports → call sites (if creating exports)
4. **Steps** — numbered, with exact commands
5. **Acceptance criteria** — testable checkboxes
```

Add a corresponding acceptance criteria requirement:

```markdown
For PRD-Lites with new exports, acceptance criteria must include:
- [ ] Every function in the wiring contract is called from its declared call site
- [ ] No new exported functions exist that aren't in the wiring contract
```

### Acceptance Criteria

- [ ] dev-partnership skill includes Wiring Contract section
- [ ] PRD-Lite structure checklist updated from 4 items to 5
- [ ] Template table is clear enough that Claude.ai can generate wiring contracts automatically
- [ ] No other sections of the skill are modified

---

## CC Session Prompts

### Prompt A: Stop Hook

```
Read /docs/pharaoh-prevention-stack-prd-lites.md, Session A.

Summary: Add check_reachability as a Stop hook in .claude/settings.json + create /check-wiring slash command.

STRICT FILE SCOPE:
- ALLOWED: .claude/settings.json, .claude/commands/check-wiring.md
- FORBIDDEN: Everything else

RULES:
- This repo uses pnpm, not npm.
- Do NOT weaken any checks. Do NOT add continue-on-error, || true, or similar bypasses.
- You are forbidden from modifying lefthook.yml, .github/workflows/ci.yml, or biome.json rule severity.
- Do NOT modify existing PostToolUse or PreToolUse hooks — only add the new Stop hook.
- If --functions-in-diff CLI flag doesn't exist, use the soft reminder approach (see Session A Step 3).
```

### Prompt B: Knip × Pharaoh Reconciliation

```
Read /docs/pharaoh-prevention-stack-prd-lites.md, Session B.

Summary: Create a reconciliation script that diffs Knip's unused-export detection against Pharaoh's check_reachability results, producing a four-quadrant categorized report.

STRICT FILE SCOPE:
- ALLOWED: scripts/reconcile-knip-pharaoh.ts, tests/scripts/reconcile-knip-pharaoh.test.ts, package.json (scripts section only)
- FORBIDDEN: Everything else

RULES:
- This repo uses pnpm, not npm.
- Do NOT weaken any checks. Do NOT add continue-on-error, || true, or similar bypasses.
- You are forbidden from modifying .claude/settings.json, lefthook.yml, .github/workflows/ci.yml, or biome.json rule severity.
- Script is diagnostic only — exit 0 always. Not a gate.
- Use tsx for execution. No new build steps.
```

### Prompt C: Wiring Contract Template

```
Read /docs/pharaoh-prevention-stack-prd-lites.md, Session C.

Summary: Add a Wiring Contract section to the dev-partnership skill's PRD-Lite template. Every PRD-Lite creating new exports must declare call sites upfront.

STRICT FILE SCOPE:
- ALLOWED: .claude/CLAUDE.md (or wherever dev-partnership rules live in this repo)
- FORBIDDEN: Everything else

RULES:
- This is a documentation/process change only. No code changes.
- Do NOT modify any other sections of the skill file.
- The wiring contract table format must match the template in Session C exactly.
```

---

## Execution Order

```
Session C (wiring contract) ← Do immediately. Zero dependencies. 15 min.
     │
     ├── Start using wiring contracts in all PRD-Lites from now on
     │
v4 Phase 1 + Phase 2A-2C ← Build check_reachability tool
     │
Session B (Knip reconciliation) ← Run during Phase 2D validation
     │
     ├── Results inform: Is CALLS edge accuracy good enough for Stop hook?
     │
Session A (Stop hook) ← Add after Phase 2D confirms accuracy
     │
v4 Phase 3+ ← PR Guard, pricing, post-merge sweep
```

Session C should happen TODAY — it's a process change that immediately improves every future PRD-Lite. Sessions A and B gate on the v4 plan's Phase 2 completion.
