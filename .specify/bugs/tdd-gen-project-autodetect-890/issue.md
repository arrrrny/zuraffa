# Bug Issue: fix(tdd) — zfa tdd gen from inside run driver fails — needs --project to find test-list

- **Slug**: tdd-gen-project-autodetect-890
- **Fetched**: 2026-09-03T00:00:00Z
- **Issue**: 890
- **URL**: https://github.com/arrrrny/zuraffa/issues/890
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: none

## Body

### Summary

When `zfa tdd run` (or `zfa tdd gen <id>`) is invoked without explicit `--project <path>`, the gen command can't locate the test-list (`specs/<feature>/tdd/test-list.md`) and reports `unknown behavior id`. The run driver stops at the first U* behavior whose artifacts don't exist yet.

### Reproduction

```bash
# From the project root:
cd /Users/ahmettok/Developer/forklift
zfa tdd gen U24 --feature 004-cloud-agent-task-dispatch
# Output:
# zfa tdd gen: unknown behavior id "U24". No matching row found in any specs/<feature>/tdd/test-list.md for feature 004-cloud-agent-task-dispatch.
# ❌ Error: Bad state: zfa tdd gen: unknown behavior id "U24"

# Works with --project:
zfa tdd gen U24 --feature 004-cloud-agent-task-dispatch --project /Users/ahmettok/Developer/forklift
# Output:
# behavior_id: U24
# source_criterion: FR-007
# ...
```

The run driver also fails the same way at the gen step:

```
[run] U24 gen -> error
```

### Root cause (as filed)

The `zfa tdd gen` command looks for the test-list by walking up from the current working directory looking for `specs/<feature>/tdd/test-list.md`. When invoked from the project root, it should find `specs/004-cloud-agent-task-dispatch/tdd/test-list.md` directly. But it doesn't.

The fix could be:

- The `ProjectRoot.find()` (added in #679) should auto-discover the project from CWD when the run driver is at the project root
- Or the run driver should always pass `--project` to its subprocess invocations

### Expected

- `zfa tdd gen <id>` and `zfa tdd run` from a repo root should work without needing explicit `--project`
- The ProjectRoot.find() logic (per #679) should resolve the project correctly when CWD is the project root

### Actual

- The run driver (per the session) is invoked without `--project` and the subprocess gen calls fail
- Each U*:gen step requires --project, so the run driver should pass it

### Verification

- A clean `zfa tdd run 004-cloud-agent-task-dispatch` from the project root should process all U* behaviors without the run driver passing --project to its subprocesses
- OR the run driver should always pass --project to subprocesses (currently doesn't)

### Context

Discovered 2026-09-02 running `zfa tdd run` on forklift spec 004 after merging all prior fixes including #679 (ProjectRoot auto-detect). The auto-detect works for the top-level run, but the run driver's subprocess invocations of `zfa tdd gen` don't auto-detect the project root.

Following STOP-ON-ROADBLOCK from zuraffa/AGENTS.md.
