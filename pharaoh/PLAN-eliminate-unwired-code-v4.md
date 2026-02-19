# Eliminate Unwired Code: v4 Plan — PR Guard

> Supersedes v3. Informed by: Pharaoh source code audit, stress testing of v3 architecture, pricing analysis, and monorepo considerations. Incorporates all decisions from planning session (Feb 2026).

## The Problem

LLM coding agents write functions, mark tasks "done," but never wire the code into the execution path. The function compiles, lints clean, passes tests — but no production code path ever reaches it.

This isn't a linting problem. It's a graph problem. You need to know: **"Is this function reachable from any production entry point?"** That requires tracing through cross-file call chains, distinguishing test callers from production callers, and understanding what constitutes an entry point (API endpoints, cron handlers, CLI commands).

## Why Pharaoh Is The Right Fix

Pharaoh already has ~80% of what's needed. The graph stores:

- **Function nodes** with `is_exported`, `complexity`, `is_async`
- **CALLS edges** — cross-file call chains traced by the Cartographer
- **IMPORTS edges** with `is_type_only` — type-only imports already distinguished
- **Endpoint nodes** with `method`, `route`, `handler_function` — auto-detected from Hono/Express/Vercel
- **CronJob nodes** with `schedule`, `handler` — auto-detected
- **EXPOSES edges** (File → Endpoint) and **HANDLES edges** (Function → CronJob)

**What's genuinely new (5 things):**

1. **File classification** — No `is_test` property on File nodes. Can't distinguish `widget.test.ts` from `widget.ts`.
2. **Event handler detection** — No `.on('event', handler)` edges. Event-driven code appears unreachable.
3. **Reverse reachability traversal** — Blast radius goes function → callers → entry points. Reachability goes entry points → callees → "is this function reachable?" The reverse Cypher query doesn't exist.
4. **`pull_request` webhook handler** — Extends existing `handleWebhookEvent()` switch.
5. **GitHub Check posting** — Report reachability results as a PR check status.

---

## Architecture Decision: In-Memory PR Analysis

**v3 proposed** indexing PR branches into Neo4j (either separate databases or branch-scoped nodes). Both approaches have significant downsides:

- **Separate databases:** Neo4j Aura limits, creation/deletion overhead, cost per database
- **Branch-scoped nodes:** Every Cypher query (20+ in neo4j-queries.ts) needs branch filtering, concurrent PRs pollute the same database, cleanup complexity

**v4 uses in-memory analysis instead.** The PR check pipeline:

1. Clone PR branch (server-side, via GitHub App installation token)
2. Run Cartographer parse in the job worker's memory — produces `ParsedFile[]`, modules, call chains
3. Query the existing main-branch graph in Neo4j for entry points and reachability data
4. Compute reachability for new/modified exports by combining in-memory parse + live graph
5. Post GitHub Check result
6. **Discard all intermediate data** — nothing persisted, no graph nodes created

**Why this is better:**

- **Zero database bloat.** No PR-scoped nodes to clean up.
- **No query changes.** Existing Cypher queries untouched.
- **Secret sauce stays hidden.** Customer sees only the Check result ("3 exports reachable, 1 unreachable"). The graph, queries, and algorithm remain completely server-side.
- **Simpler implementation.** No branch property plumbing, no deactivation logic, no concurrent-PR conflicts.

**Tradeoff accepted:** PR branch graph is not queryable via MCP tools. This is fine — the automated check is the only consumer of PR-branch data.

---

## Capability 1: File Classification

Add `is_test: boolean` property to File nodes. The Cartographer already walks all files and creates File nodes — this adds one classification step.

### Classification Rules

```typescript
function isTestFile(filePath: string): boolean {
  if (/\.(test|spec)\.(ts|tsx|js|jsx)$/.test(filePath)) return true;
  if (filePath.includes('__tests__/')) return true;
  if (filePath.includes('__mocks__/')) return true;
  if (/\/tests?\//.test(filePath)) return true;
  if (filePath.startsWith('test/') || filePath.startsWith('tests/')) return true;
  if (filePath.includes('/fixtures/')) return true;
  if (/\.stories\.(ts|tsx)$/.test(filePath)) return true;
  return false;
}
```

### Where It Goes

- `src/parser/file-walker.ts` — export `isTestFile()` for use by Cartographer and in-memory analysis
- `src/graph/graph-writer.ts` — add `is_test` property to File node MERGE
- File data construction in `writeGraph` — compute `is_test: isTestFile(f.path)` per file

### Impact on Existing Tools

- `get_unused_code` can filter: `WHERE NOT file.is_test` — exclude test-only callers
- `get_blast_radius` can report test vs production callers separately

---

## Capability 2: Event Handler Detection

New detector (`src/detectors/event-handler-detector.ts`) following the existing detector pattern.

### What It Detects

```typescript
// EventEmitter patterns
emitter.on('event', handler)
emitter.once('event', handler)
emitter.addListener('event', handler)
eventBus.on('user.created', sendWelcomeEmail)

// Framework lifecycle patterns
app.use(middleware)
router.use('/path', middleware)
```

### Graph Output

- **EventBinding nodes** with `event_name`, `pattern` properties
- **HANDLES_EVENT edges** from Function → EventBinding
- **EMITS_EVENT edges** from Function → EventBinding

---

## Capability 3: Entry-Point Reachability Query

Core Cypher query traces from entry points (endpoints, crons, event handlers) through CALLS edges, filtering to production files only. New MCP tool `check_reachability` exposes this. `get_unused_code` enhanced to use reachability instead of raw caller count.

---

## Capability 4: Allowlist (`.pharaoh.yml`)

Ships BEFORE the PR gate. Supports `allowed_orphans`, `entry_points`, and `not_test` overrides.

---

## Capability 5: Reference-Count Backup Layer

For every function flagged unreachable by graph, check if function name appears in production source files. Two-layer agreement required to flag as unreachable. Three-tier output: reachable (green) / likely reachable (yellow, advisory) / unreachable (red).

---

## Capability 6: PR Guard (Automated PR Check)

Webhook pipeline: pull_request → debounce (30s) → clone → parse (in-memory) → diff → reachability → reference-count backup → allowlist → GitHub Check. Advisory mode by default.

---

## Capability 7: Post-Merge Sweep

After default branch push triggers Cartographer refresh, run `check_reachability` on all exports. No auto-ticketing (v3 dropped). Data available via `get_unused_code`.

---

## Capability 8: Claude Code Integration

Wire-check slash command and CLAUDE.md pre-PR checklist.

---

## Two-Layer Detection: 99%+ Confidence

| Scenario | Graph | Ref Check | Combined | Blocks Merge? |
|----------|-------|-----------|----------|---------------|
| Function with zero references anywhere | Caught | Caught | **100%** | Yes |
| Function referenced only by test files | Caught | Caught | **100%** | Yes |
| Function in dead call chain | Caught | Caught | **100%** | Yes |
| Function only barrel re-exported | Caught | Caught | **100%** | Yes |
| Function wired through event emitter | Caught | Caught | **100%** | Yes |
| Function passed as callback | Missed | Caught | **99%+** | Advisory |
| Function in config object | Missed | Caught | **99%+** | Advisory |
| `eval()` / runtime string dispatch | Missed | Missed | **Not caught** | No (~0.1%) |

---

## Execution Plan

### Phase 1: Foundation (~6 hrs, parallel)
1A: File classification (isTestFile + is_test property)
1B: Reachability Cypher queries
1C: Event handler detector

### Phase 2: MCP Tools + Validation (~8 hrs)
2A: check_reachability MCP tool
2B: Enhance get_unused_code
2C: Re-map repos
2D: Validate accuracy (GATE — do not proceed until passing)

### Phase 3: Allowlist + PR Guard (~11 hrs)
3A: .pharaoh.yml parser
3B-3F: Webhook, analysis pipeline, GitHub Check, wiring

### Phase 4: Pricing (~4 hrs)
Stripe integration, $39/$99 base + $10/repo PR Guard add-on

### Phase 5: Post-Merge Sweep + Claude Code (~4 hrs)

### Phase 6: Dogfood + Launch (ongoing)

**Critical path: ~25 hrs active work to PR Guard.**

---

## Pricing

| Plan | Price | Includes |
|------|-------|----------|
| Personal | $39/month | All MCP tools, check_reachability, dead code detection |
| Team | $99/month | Multi-user, org-wide graph |
| PR Guard add-on | $10/repo/month | Automated PR checks (first repo free) |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| CALLS edges miss real calls | Medium | Low (mitigated) | Reference-count backup, Phase 2D validation, allowlist |
| False positives on first customer | Medium | High | Default advisory mode, allowlist ships with PR Guard |
| Rapid PR pushes overwhelm queue | Low | Medium | 30s debouncing |
| Neo4j query performance at scale | Low | Medium | Bounded depth (*0..10), precompute if needed |

> See companion doc: PREVENTION-STACK-PRD-LITES.md for the three prevention layers (Stop hooks, Knip reconciliation, wiring contracts) that complement this detection plan.