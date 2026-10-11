# Issue: zfa tdd gen: --project flag ignored — reads wrong test-list.md from monorepo sibling/corpus dirs

- **GitHub issue**: #1272 (https://github.com/arrrrny/zuraffa/issues/1272)
- **Severity**: high (workflow-blocking for monorepo users)
- **Filed by**: ahmettok during apps/login_demo spec 001-login-ui build
- **Slug**: tdd-gen-project-flag-ignored

## Bug Report

**Repro:**

```bash
cd /Users/ahmettok/Developer/zuraffa   # monorepo root
zfa tdd gen A1 --project apps/login_demo
```

**Expected:** zfa looks for `apps/login_demo/specs/001-login-ui/tdd/test-list.md` and generates the A1 widget test+subject pair under that project.

**Actual:** First call (without `--project`) reads `zuraffa/specs/<feature>/tdd/test-list.md` (none), errors out. With `--project apps/login_demo`, the runner resolves the project root but then somehow walks UP and reads the wrong `test-list.md` from a parallel `example/specs/004-login-ui/tdd/test-list.md` directory, which has a different shape (7-column format) than the canonical 4-column format:

```
❌ Error: Bad state: zfa tdd gen: malformed test list —
test-list.md line 23: expected 4 columns (id/behavior/traces/state),
found 7: "| A1 | acceptance | User Story 1, Scenario 1 | DONE | toggle
method is generated across all layers | test/integration/toggle_method_test.dart | ..."
```

**Root cause:** The `test-list.md` parser scans `specs/<feature>/tdd/test-list.md` across the entire filesystem (or workspace) rather than scoping to the `--project` directory. Confusingly-named example/corpus directories (`example/specs/004-login-ui/`, `.worktrees/pr-XXX/specs/...`, `corpus/regression/.../specs/u2-flow/`) all have `test-list.md` files with varying schemas, and the parser picks whichever it hits first.

**Suggested fix:** `zfa tdd gen` should ONLY look at `<project>/specs/<feature>/tdd/test-list.md` when `--project` is given. Reject any `test-list.md` outside the project root.

**Workaround used:** Ran `zfa tdd gen A1` etc. from inside `apps/login_demo/` directly (so the working directory IS the project root). This worked but the spec/test-list.md is one level above the project root and had to be referenced relatively.
