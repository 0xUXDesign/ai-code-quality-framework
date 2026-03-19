---
description: Generate implementation session prompts from a PRD or research doc
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion
argument: doc-path
---

Generate self-contained, copy-paste-ready prompts for parallel Claude Code sessions that implement a PRD or research document.

## Input Resolution

1. If `$ARGUMENTS` is provided and non-empty, use it as the doc path
2. If no argument: run `ls -t docs/plans/*.md docs/sessions/*.md 2>/dev/null | head -1` to find the most recently modified doc
3. If nothing found, ask the user which file to use
4. **Print the resolved doc path prominently** so the user can confirm before proceeding:
   ```
   Document: docs/plans/dashboard-fixes-prd.md
   ```
5. Read the full document content

## Analysis

Analyze the document and determine:

### Work Units
- Identify **logical work units** — groups of related changes that should ship as one PR
- A work unit has cohesive scope: same module area, same feature, or tightly coupled changes
- Each work unit = one session = one worktree = one PR

### Complexity Assessment
- **Simple** (1 session): single file or 2-3 files, straightforward changes, no schema changes
- **Medium** (1 session, but more steps): 3-5 files, may include schema changes or new functions
- **Complex** (consider splitting): 6+ files, multiple modules, schema + logic + UI changes

### Dependency Graph
- Which units depend on others? (e.g., schema changes must land before code that uses them)
- Which units are fully independent and can run in parallel?
- Draw the dependency graph explicitly

## Output Format

### Summary

Start with a brief breakdown:

```
## Session Breakdown

**Document:** <path>
**Sessions:** <N> implementation + <0 or 1> review = <total> total
**Parallelization:** Sessions <X> and <Y> can run in parallel. Session <Z> depends on <X>.

| Session | Scope | Files | Depends On |
|---------|-------|-------|------------|
| 1       | ...   | ~N    | —          |
| 2       | ...   | ~N    | —          |
| 3       | ...   | ~N    | 1          |
| R       | Review all sessions against plan | —  | All above |
```

### Session Prompts

For each session, generate a fenced code block containing a complete, self-contained prompt. The prompt must work when pasted into a **fresh** Claude Code window with zero prior context.

Each prompt follows this exact structure:

````
```
## Session N: <descriptive-title>

### Setup
Switch to a worktree named `<kebab-case-name>` for this work.

### Reference
Read `<path-to-prd>` for full context. This session implements <specific section/issues>.

### Scope
<Exactly which issues, sections, or changes this session handles. Be specific — list issue numbers, section headers, or bullet points from the doc.>

### Key Files
**Read first:**
- `<path>` — <why>

**Modify:**
- `<path>` — <what changes>

### Implementation Steps
1. <step>
2. <step>
3. ...

### Testing
- <what tests to write>
- <what to verify manually>
- Run `pnpm run quality` before finishing

### Exit
Commit your work and open a PR. PR title: `<suggested-title>`

### Boundaries
Do NOT touch:
- <files/modules outside scope>
- <other issues from the doc that belong to different sessions>
```
````

### Review Session (auto-generated when >1 implementation session)

If there are **2 or more** implementation sessions, generate one final review session prompt as the last session. This session evaluates all implementation work against the original plan.

**CRITICAL: Plan file availability.** The review session MUST be able to read the plan file. Before generating the review prompt:
1. Determine the absolute path to the plan file (the document being sessionized)
2. If the plan file is uncommitted, **commit it now** so all worktrees and future sessions can access it
3. Include the plan file path as both a relative repo path AND an absolute path in the review prompt

The review session follows this structure:

````
```
## Session R: Review against plan

### Setup
Pull the latest main branch before starting: `git checkout main && git pull`

### Plan Reference
**CRITICAL — Read this file first. The entire review is a comparison against this plan.**
Read `<plan-file-path>` (absolute: `<absolute-plan-file-path>`).
If the file doesn't exist at the relative path, try the absolute path.

### Session Inventory
The plan defined <N> implementation sessions:
<For each session, one line: session number, title, scope summary, key branch/PR name pattern>

### Review Procedure

For each session below, check the actual codebase against the plan's specifications.

#### Session <N>: <title>
**Branch/PR pattern:** `<worktree-name or branch pattern>`

**Files to verify:**
- [ ] `<path>` — <what should exist or have changed, per the plan>

**Tests to verify:**
- [ ] `<test-file-path>` exists
- [ ] <specific test case name> — <what it should assert>

**"Done When" criteria:**
- [ ] <criterion from plan>

<repeat for each session>

### Quality Gate
Run and report results:
1. `pnpm build` — compiles?
2. `pnpm test` — all pass?
3. `pnpm run lint` — clean?

### Evaluation

For each session, produce a scorecard:

| Session | Status | Deliverables | Tests | Issues |
|---------|--------|--------------|-------|--------|
| N       | Complete/Partial/Not Started | N/M | N/M | count |

For any PARTIAL or NOT STARTED session, list:
- What's missing (specific files, functions, routes, tests)
- What's deviated from the plan
- Security invariant violations

### Output
End with a prioritized "Recommended Next Steps" list — what to fix/finish first.

If there is incomplete work, generate follow-up session prompts scoped to ONLY the remaining work.
```
````

If only **1 implementation session** is generated, skip the review session entirely.

## Delivery

**IMPORTANT: Always paste the full output into the current conversation as a document.** Do not just describe the sessions — output the complete summary table and all session prompts (including the review session if applicable) directly so the user can copy them.

## Rules

- **Plan file must be committed**: Before generating ANY session prompts, verify the plan/PRD file is committed to the repo. If it's not, commit it so that all worktrees and review sessions can read it.
- **Self-contained**: each prompt must include everything a fresh session needs. No "see above" or "as discussed" references.
- **Worktree names**: use kebab-case derived from the work unit (e.g., `fix/billing-session-persistence`, `feat/repo-count-display`)
- **File paths**: use actual paths from the document or discovered via codebase search. Never guess.
- **Scope boundaries**: explicitly tell each session what NOT to touch. This prevents sessions from stepping on each other.
- **Dependency ordering**: if Session 3 depends on Session 1, say so explicitly in Session 3's prompt: "This session depends on Session 1 being merged first. Pull main before starting."
- **No meta-commentary in prompts**: the prompts are instructions, not explanations. Keep them direct and actionable.
- **Verify file existence**: before listing files in prompts, confirm they actually exist in the codebase using Glob/Grep.
- **Embed specifics in review session**: the review prompt should know exactly which files to check and which criteria to evaluate.
