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
