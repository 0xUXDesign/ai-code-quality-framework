---
description: Adversarial security review via OpenAI model — second opinion from a different AI
---

You are orchestrating an adversarial security review of the current branch using an OpenAI model. Claude hydrates the prompt with codebase context, then dispatches to a different model for a cold-start review — different model, different blind spots.

## Phase 0: Prerequisites

Run these checks **sequentially**. Stop at the first failure.

1. Check if `OPENAI_API_KEY` is set:
   ```bash
   echo "${OPENAI_API_KEY:+set}"
   ```
   If NOT set, print:
   ```
   review-codex: OPENAI_API_KEY not set.

   To use this command:
     export OPENAI_API_KEY=sk-...

   Or add it to your shell profile (~/.zshrc, ~/.bashrc).
   This command requires an OpenAI API key to dispatch reviews to a different model.
   ```
   **STOP.**

   If set:
   - `API_BASE="https://api.openai.com/v1"`
   - `MODEL="gpt-4.1"` (or override with `REVIEW_CODEX_MODEL` env var if set)
   - Print: `Backend: OpenAI API (direct)`

2. Get the diff stat:
   ```
   git diff main --stat
   ```
   If empty (no changes vs main), print:
   ```
   review-codex: No changes to review (branch matches main).
   ```
   **STOP.**

3. Print header:
   ```
   Review-Codex: <branch> @ <directory> (<model>)
   ```
   Use `git branch --show-current` and `pwd` for the values.

## Phase 1: Gather Context

Collect all of the following. Run independent steps in parallel where possible.

### 1a. Git data
- `git diff main` — full diff (save to variable for Phase 2)
- `git diff main --name-only` — affected file list

### 1b. Codebase reconnaissance (best-effort)

Search the codebase for context about the changed areas:
1. Read `CLAUDE.md` if it exists — extract architecture section and any security rules
2. For the most-changed files, read surrounding context (imports, module structure)
3. If Pharaoh MCP tools are available, use `get_codebase_map` and `get_blast_radius` on the most-changed functions

### 1c. Large diff handling

If the diff exceeds 2000 lines:
- Filter to only security-relevant files: anything in paths containing `auth`, `crypto`, `db`, `api`, `middleware`, `config`, `token`, `session`, `oauth`, `webhook`, `secret`, `key`, `password`, `login`, `permission`, `tenant`, `admin`, or handler/route files.
- Print a note: `Large diff (N lines). Filtered to M security-relevant files. Run on a smaller branch for full coverage.`
- Use the filtered diff for the prompt.

## Phase 2: Construct the Prompt

Build the prompt content and JSON payload.

### Step 1: Write the user content to a temp file

Write the following sections concatenated to `/tmp/review-codex-content-$$.txt`:

```
ARCHITECTURE:
<Codebase map or architecture from CLAUDE.md, or "Not available">

AFFECTED FILES:
<File list from git diff --name-only>

PROJECT SECURITY RULES:
<Security rules from CLAUDE.md, or "None specified">

REVIEW CHECKLIST — evaluate every item:
1. Authentication & Authorization: Are new endpoints/handlers protected? Can User A access User B's resources?
2. Injection: SQL, command, XSS, template injection via user-controlled input
3. Sensitive Data Exposure: Tokens, keys, session IDs in URLs/logs/error messages/client bundles
4. Tenant Isolation: Cross-tenant data access, missing ownership checks
5. Cryptography: Weak algorithms, hardcoded secrets, missing encryption at rest/transit
6. Supply Chain: New dependencies with known vulnerabilities, unpinned versions
7. Error Handling: Stack traces leaked to clients, errors swallowed silently hiding security failures
8. Race Conditions: TOCTOU in auth checks, concurrent access to shared state

DIFF TO REVIEW:
<the full diff or filtered diff>
```

### Step 2: Build the JSON payload

```bash
SYSTEM_PROMPT='You are an adversarial security reviewer. The code was written with AI assistance from a different model. Your job is to find what they missed — security vulnerabilities, auth gaps, data exposure, and architectural violations. Be specific and cite file:line.

For each finding, output exactly:
SEVERITY: CRITICAL | HIGH | MEDIUM | LOW
FILE: <file path>:<line number>
TITLE: <one-line summary>
EXPLOIT: <concrete attack scenario — how would an attacker exploit this?>
FIX: <specific code change to remediate>

If no security issues found, output: NO_ISSUES_FOUND

End with a summary count: N CRITICAL, N HIGH, N MEDIUM, N LOW'

jq -n \
  --arg model "$MODEL" \
  --arg system "$SYSTEM_PROMPT" \
  --rawfile user /tmp/review-codex-content-$$.txt \
  '{model: $model, messages: [{role: "system", content: $system}, {role: "user", content: $user}]}' \
  > /tmp/review-codex-payload-$$.json
```

## Phase 3: Dispatch to OpenAI

Call the Chat Completions API via curl. Use the Bash tool's `timeout` parameter (300000ms / 5 minutes).

```bash
curl -s "$API_BASE/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d @/tmp/review-codex-payload-$$.json \
  > /tmp/review-codex-response-$$.json
```

Parse the response:
```bash
python3 -c "
import json, sys
r = json.load(open('/tmp/review-codex-response-$$.json'))
if 'error' in r:
    print('ERROR:', json.dumps(r['error'], indent=2))
    sys.exit(1)
if 'choices' in r:
    print(r['choices'][0]['message']['content'])
    sys.exit(0)
print('UNEXPECTED RESPONSE:', json.dumps(r, indent=2)[:1000])
sys.exit(1)
"
```

**Error handling:**
- If the Bash tool times out: print "Review timed out after 5 minutes. Consider reviewing fewer files or a smaller diff."
- If response is empty or malformed: print the raw response for debugging.

**Cleanup (ALWAYS run, even on failure):**
```bash
rm -f /tmp/review-codex-content-$$.txt /tmp/review-codex-payload-$$.json /tmp/review-codex-response-$$.json
```

## Phase 4: Present Findings

### 4a. Raw findings
Print the model's response under a clear header:

```
## OpenAI Security Findings
<model output>
```

### 4b. Claude's assessment

For **each** finding reported, add your own assessment by reading the actual code at the cited file:line. Use one of:

- **AGREE** — You confirm the vulnerability is real. Explain the risk.
- **DISAGREE** — False positive. Explain specifically why (e.g., "mitigated by auth middleware at server.ts:142").
- **CONTEXT** — Finding is directionally correct but missing context. Add what the other model missed.

### 4c. Combined verdict

End with:

```
## Combined Verdict

### Action Items (ordered by severity)
1. [CRITICAL/HIGH/MEDIUM/LOW] file:line — description — AGREE/DISAGREE/CONTEXT

### Summary
- OpenAI found: N issues (X critical, Y high, ...)
- Claude confirms: M are real, K are false positives
- Recommendation: APPROVE / APPROVE WITH WARNINGS / REQUEST CHANGES
```

## Important Notes

- Do NOT modify any files. This is read-only analysis.
- If the other model finds NO_ISSUES_FOUND, still do a brief independent security scan of the diff yourself and report anything you see.
- **Cleanup is non-negotiable.** Temp files MUST be cleaned up even if the API call fails or times out.
