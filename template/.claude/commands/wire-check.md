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
