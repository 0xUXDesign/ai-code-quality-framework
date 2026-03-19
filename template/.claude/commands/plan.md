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
