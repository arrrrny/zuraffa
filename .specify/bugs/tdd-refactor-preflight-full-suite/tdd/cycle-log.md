# Cycle Log — tdd-refactor-preflight-full-suite (issue #922)

Bug-driven TDD cycle for `fix(922): refactor preflight excludes pre-existing
red from done gate`. Evidence below records runs actually executed on branch
`fix/922-refactor-preflight-preexisting-red` (2026-09-03); every entry names
its command and observed outcome. The reproduction suite is
`test/plugins/tdd/bug_922_refactor_preflight_baseline_test.dart`.

## Cycle: 922 (red)

- behavior: 922
- kind: red
- classification: assertionFailure
- criterion: issue #922 expected — "mark behaviors done when make returns
  green even if the refactor preflight fails for suite-wide reasons"
- test: test/plugins/tdd/bug_922_refactor_preflight_baseline_test.dart
- command: `dart test test/plugins/tdd/bug_922_refactor_preflight_baseline_test.dart --preset=all`
- exit: 1
- at: 2026-09-03T00:00:00.000Z (pre-fix)
- output:
```
7 failing / 1 passing (pre-fix). The end-to-end driver reproduction emitted
the exact issue #922 signature:

  zfa tdd run: feature 090-tdd-fixture — 1 behavior(s)
     suite baseline: dart test (once per run — issue #741)
     baseline cached for this run: specs/090-tdd-fixture/tdd/run-baseline.json
       (1 pre-existing failure(s)); make steps reuse it instead of re-running
       the suite
  [run] B-001 refactor -> not-green
  [run] B-001 refactor -> deferred (phase 2)
     preflight refused (suite not green) — the deferred refactor re-runs in
       the phase-2 refactor pass
  [run] B-001 refactor -> not-green (phase 2)
  [run] B-001 refactor -> skipped (suite not green)
  run: feature=090-tdd-fixture result=stopped pending=0 red=0 green=1 done=0
    stopped_at=B-001:refactor

Failing (pre-fix): the five baseline-tolerance refactoring tests failed on
the then-unknown `--suite-baseline` option ("Could not find an option named
suite-baseline"); the driver argv test failed because refactor spawns did
not carry `--suite-baseline`; the end-to-end test failed on
result=stopped green=1 done=0 stopped_at=B-001:refactor — the issue's own
signature (green=N, done=0). The standalone no-flag refusal test passed
pre-fix (spec 048 FR-001 already enforced) and must keep passing.
```

## Cycle: 922 (green)

- behavior: 922
- kind: green
- criterion: issue #922 expected — 13 green behaviors reach done; the run
  completes; pre-existing red no longer blocks the done gate
- test: test/plugins/tdd/bug_922_refactor_preflight_baseline_test.dart
- command: `dart test test/plugins/tdd/bug_922_refactor_preflight_baseline_test.dart --preset=all`
- exit: 0
- at: 2026-09-03T00:00:00.000Z (post-fix)
- output:
```
9/9 passing (post-fix). The end-to-end driver reproduction with the REAL
`zfa tdd refactor` in the loop (exec forwarder, real `dart test` suites,
real pass registry) now emits:

  run: feature=090-tdd-fixture result=complete pending=0 red=0 green=0 done=1

with run-state behavior_states = {"B-001": "done"} and the refactor's
cycle-log evidence recording the tolerated pre-existing red honestly.
```

## Regression checks (post-fix)

- `dart test test/plugins/tdd/refactor_command_test.dart
  test/plugins/tdd/run_baseline_cache_test.dart --preset=all` → 21 passing,
  0 failing (spec 048 contracts and the issue #741 baseline-cache contract
  unchanged).
- `dart test test/plugins/tdd/run_command_test.dart
  test/plugins/tdd/run_command_path_format_test.dart --preset=all` →
  45 passing, 1 failing — the 1 (`bug #691` unexpected-green test) fails
  identically on the pristine master tree (pre-existing red, verified by
  `git stash` + re-run; out of scope for #922).
- `dart test test/plugins/tdd/scenarios/sc_013_run_drives_feature_test.dart
  test/plugins/tdd/scenarios/sc_014_run_resumes_test.dart
  test/plugins/tdd/scenarios/sc_015_run_stops_on_failure_test.dart
  test/plugins/tdd/scenarios/sc_016_run_summary_contract_test.dart
  --preset=all` → 16 passing, 0 failing.
- `dart test test/plugins/tdd/tdd_command_smoke_test.dart
  test/plugins/tdd/make_command_test.dart --preset=all` → 40 passing,
  4 failing — identical on pristine master (pre-existing red; verified by
  stash + re-run).
- `tools/run_tests_chunked.sh` (fast tier, 68 chunks via
  `tools/run_chunks_range.sh` in three batches) → every chunk passed, 0
  failures: the fix introduces NO NEW failures in the fast suite.
