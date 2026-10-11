# Cycle Log: 077-make-engine-preset

## Baseline (zfa tdd plan)

- **Date**: 2026-09-05
- **Derived by**: `zfa tdd plan 077-make-engine-preset` (deterministic, exit 0)
- **Behaviors**: 12 acceptance (A1–A12), 12 unit (U1–U12) — 24 total, all PENDING
- **Existing coverage**: engine slice generation (U1–U4, FR-001…004) and the flutter-import
  guard (part of U4) have prior spec-1002 coverage; the loop should mark those behaviors
  covered only where a live test proves them.
## Cycle: A1 (red)

- behavior: A1
- kind: red
- classification: assertionFailure
- evidence: A1 (AC-1) A1 — all layers of the engine slice for each requested method are generated and the command exits successfully.
- subject-hash: f4e1163e5b5ba3afa0424e26849e3f1739a32624e3a697e9ac13326758b57198
- criterion: AC-1
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/077-make-engine-preset/a1_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/077-make-engine-preset/a1_test.dart --plain-name "all layers of the engine slice for each requested method are generated and the command exits successfully."`
- exit: 1
- at: 2026-09-05T09:52:17.014141Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/077-make-engine-preset/a1_test.dart
00:00 +0: A1 (AC-1) A1 — all layers of the engine slice for each requested method are generated and the command exits successfully.
00:00 +0 -1: A1 (AC-1) A1 — all layers of the engine slice for each requested method are generated and the command exits successfully. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a1 not implemented>
  
  package:matcher                                    expect
  test/tdd/077-make-engine-preset/a1_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/077-make-engine-preset/a1_test.dart: A1 (AC-1) A1 — all layers of the engine slice for each requested method are generated and the command exits successfully.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 5f95a250d7fb6b0596ce080db2f2d44479a777ee3e9d5bf9f6d1820c80479940


## ROADBLOCK: A1:make runner-error (STOP-ON-ROADBLOCK, AGENTS.md)

- **Date**: 2026-09-05
- **Command run**: `zfa tdd run 077-make-engine-preset --timeout 25`
- **Expected**: the loop drives A1 gen → verify-red → make (green) and continues through all 24 behaviors.
- **Actual**: A1 gen ok, verify-red certified, then `make -> runner-error` (reproduced standalone with `zfa tdd make A1 --feature 077-make-engine-preset`): "the suite baseline did not produce a usable snapshot. Refusing to generate without a trustworthy pre-run failure set." baseline exit: -1, failed: 0. No `run-baseline.json` was written for the feature; the loop cannot pass `A1:make` on any retry.
- **Root cause** (traced in source): `lib/src/plugins/tdd/commands/run_driver_core.dart:406-409` runs the run-level suite baseline via `const SingleTestRunner().runSuite(suiteTemplate: ..., workingDirectory: ...)` **without forwarding the `--timeout` override**, so it uses `TddTimeouts.defaultSuite` (hardcoded 10 minutes, `tdd_timeout.dart:48`). The repo's full fast `dart test` suite now takes well over 10 minutes, so the baseline child is killed (`ProcessTimeoutException` → `SuiteRunRecord.exitCode = -1, timedOut: true`), the snapshot is unparseable, and no baseline cache is written. `zfa tdd make` then runs its own live baseline which hits the same 10-minute wall (same exit -1). `--timeout 25` on `zfa tdd run` also does not rescue the make fallback path (make is spawned with its own default when the cache is missing — observed in the same run).
- **Suggested fix**: propagate the run-level `timeoutOverride` into `runSuite(...)` for the baseline (and ensure the driver passes `--timeout` when spawning `tdd make`), and/or scope the baseline (chunked runner / changed-test heuristic) for repos whose fast suite exceeds 10 minutes.
- **Action per AGENTS.md**: goal stopped; GitHub issue filed; resume only after the issue is MERGED and a new goal references this PROGRESS/cycle-log entry.
