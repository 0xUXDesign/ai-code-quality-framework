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
