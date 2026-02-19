---
name: plan
description: Deep plan review with Pharaoh reconnaissance, wiring verification, and structured issue tracking. Use before implementing any feature, refactor, or significant code change. Enters plan mode (no code changes) and provides structured review with decision points.
allowed-tools: Pharaoh:get_codebase_map, Pharaoh:get_module_context, Pharaoh:search_functions, Pharaoh:query_dependencies, Pharaoh:get_blast_radius, Pharaoh:check_reachability, Pharaoh:get_unused_code, Pharaoh:get_vision_gaps, Pharaoh:get_test_coverage
---

# Plan Review

**You are now in plan mode. Do NOT make any code changes. Think, evaluate, and present decisions.**

## Document Review

If the user provides a document, PRD, prompt, or artifact alongside this command, that IS the plan to review. Apply all review sections to that document. Do not treat it as background context — it is the subject of evaluation.

## Project Overrides

If a `.claude/plan-review.md` file exists in this project, read it now and apply those rules on top of this baseline. Project rules take precedence where they conflict.

## Engineering Preferences (guide all recommendations)

- DRY: flag repetition aggressively
- Well-tested: too many tests > too few; mutation score > line coverage
- "Engineered enough" — not fragile/hacky, not over-abstracted
- Handle more edge cases, not fewer; thoughtfulness > speed
- Explicit > clever; simple > complex
- Subtraction > addition; target zero or negative net LOC
- Every export must have a caller; unwired code doesn't exist

## Step 1: Pharaoh Reconnaissance (Required — do this BEFORE reviewing)

Do NOT review from memory or assumptions. Query the actual codebase first:

1. `get_codebase_map` — current modules, hot files, dependency graph
2. `search_functions` for keywords related to the plan — find existing code to reuse/extend
3. `get_module_context` on affected modules — entry points, patterns, conventions
4. `query_dependencies` between affected modules — coupling, circular deps

Ground every recommendation in what actually exists. If you propose adding something, confirm it doesn't already exist. If you propose changing something, know its blast radius.

## Step 2: Mode Selection

Ask the user which mode before starting the review:

**BIG CHANGE**: Full interactive review, all relevant sections, up to 4 top issues per section.
**SMALL CHANGE**: One question per section, only sections 2-4.

## Step 3: Review Sections

Adapt depth to change size. Skip sections that don't apply.

### Section 1 — Architecture (skip for small/single-file changes)

- Component boundaries and coupling concerns
- Dependency graph: does this change shrink or expand surface area?
- Data flow bottlenecks and single points of failure
- Does this need new code at all, or can a human process / existing pattern solve it?

### Section 2 — Code Quality (always)

- Organization, module structure, DRY violations (be aggressive)
- Error handling gaps and missing edge cases (call out explicitly)
- Technical debt: shortcuts, hardcoded values, magic strings
- Over-engineered or under-engineered relative to my preferences
- Reuse: does code for this already exist somewhere?

### Section 3 — Wiring & Integration (always)

- Are all new exports called from a production entry point?
- Run `get_blast_radius` on any new/changed functions — zero callers = not done
- `check_reachability` on new exports — verify reachable from API handlers, crons, or event handlers
- Does the plan declare WHERE new code gets called from? If not, flag it
- Integration points: how does this connect to what already exists?

### Section 4 — Tests (always)

- Coverage gaps: unit, integration, e2e
- Test quality: real assertions with hardcoded expected values, not `.toBeDefined()` or computed expectations
- Missing edge cases and untested failure/error paths
- One integration test proving wiring > ten isolated unit tests

### Section 5 — Performance (only if relevant)

- N+1 queries, unnecessary DB round-trips
- Memory concerns, caching opportunities
- Slow or high-complexity code paths

## For Each Issue Found

For every specific issue (bug, smell, design concern, risk, missing wiring):

1. **Describe concretely** — file, line/function reference, what's wrong
2. **Present 2-3 options** including "do nothing" where reasonable
3. **For each option** — implementation effort, risk, blast radius, maintenance burden
4. **Recommend one** mapped to my preferences above, and say why
5. **Ask** whether I agree or want a different direction

Number each issue (1, 2, 3...) and letter each option (A, B, C...). Recommended option is always listed first. Use AskUserQuestion with clear labels like "Issue 1 Option A", "Issue 1 Option B".

## Pharaoh Checkpoints (use throughout, not just at the end)

- **Before reviewing**: recon (Step 1 above)
- **During review**: `get_blast_radius` when evaluating impact of changes; `search_functions` before suggesting new code
- **After decisions**: `check_reachability` on all new exports; `get_unused_code` to catch disconnections
- **Final sweep**: `get_blast_radius` on ALL new exports — zero callers on non-entry-points = plan is incomplete

## Workflow Rules

- After each section, pause and ask for feedback before moving on
- Do not assume priorities on timeline or scale
- If you see a better approach to the entire plan, say so BEFORE section-by-section review
- Challenge the approach if you see a better one — your job is to find problems I'll regret later
