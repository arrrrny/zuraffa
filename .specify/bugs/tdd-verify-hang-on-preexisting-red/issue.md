# Bug Issue: fix(tdd verify): verification hangs on full-suite baseline with many pre-existing failures

- **Slug**: tdd-verify-hang-on-preexisting-red
- **Fetched**: 2026-09-03
- **Issue**: 924
- **URL**: https://github.com/arrrrny/zuraffa/issues/924
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

### Summary

`zfa tdd verify --feature <name>` hangs indefinitely when the project has many pre-existing test failures (24+ in spec 004). The verify step tries to run the full suite as part of the mutation audit preflight and never returns. The process must be killed manually.

### Reproduction

```bash
# In forklift repo (24 pre-existing test failures):
zfa tdd verify --feature 004-cloud-agent-task-dispatch
# Process runs indefinitely, no output, no exit
# Must be killed with SIGKILL

# In contrast, verify with --feature and a feature where the suite is mostly green:
zfa tdd verify --feature <other-feature>
# Returns within 30-60s with a verification.md
```

### Root cause

`zfa tdd verify` runs the full `dart test` as a preflight before the mutation audit. With 24+ pre-existing failures, the preflight takes a long time (the test runner has to load all the failing test files and report the load errors). The verify command doesn't have a timeout for this preflight.

Combined with the per-preset config lookup (`mutation-test.xml` not found in forklift), the verify command spends time on both the full suite preflight AND the mutation config resolution before the `gate: not_assessed` error.

### Expected

- `zfa tdd verify` should respect a `--timeout <minutes>` flag (same as `zfa tdd make`) and exit non-zero on timeout
- The full-suite preflight should use the per-behavior test (already in the TDD profile's `single` template) when the feature has its own test files
- `gate: not_assessed` (missing mutation config) should be returned immediately without running the full suite

### Actual

`zfa tdd verify` hangs indefinitely. The 30-minute `WaitFor` timeout fires while the process is still running the suite preflight.

### Verification

- A `zfa tdd verify` with many pre-existing failures returns within a few minutes (not 30+) with a `gate: not_assessed` (or the appropriate non-blocking gate)
- The verify process respects `--timeout` and exits with a runner-error classification on timeout

### Context

Discovered 2026-09-03 while running spec 004. After the tdd run completed 13 green behaviors, the verify step was needed to produce `verification.md`. It hung on the full-suite preflight (24 pre-existing failures) for >30 minutes and had to be killed. The expected `gate: not_assessed` (no `mutation-test.xml`) was never reached because the preflight didn't complete.

Following STOP-ON-ROADBLOCK from zuraffa/AGENTS.md.
