# Red Evidence — 1529 make timeout (receipt, scaled budget, trimmed re-certification)

**Feature**: 1529-make-timeout-diagnosable-scaled-budget
**Protocol**: every behaviour's first failing run is recorded here before
the green implementation lands. The M1/M2 reds below were RE-DERIVED on
2026-09-13 by running the spec-1529 test files against the `master`
sources in an isolated `git worktree` (the green implementation had
already landed on this branch in d562791d, so the original first-fail
runs predate this file; the re-derivation reproduces them exactly). The
M3 reds are the live first-fail runs from this session.

## M1/M2 reds — re-derived against `master` (b621f38b)

### U1/U2 (`scaledStepBudget`), U5/U6 (`StepTimeoutReceipt`) — step_timeout_receipt_test.dart

```text
  test/plugins/tdd/services/step_timeout_receipt_test.dart:20:8: Error:
    Error when reading 'lib/src/plugins/tdd/services/step_timeout_receipt.dart':
    No such file or directory
  test/plugins/tdd/services/step_timeout_receipt_test.dart:26:22: Error:
    Method not found: 'scaledStepBudget'.
  test/plugins/tdd/services/step_timeout_receipt_test.dart:36:34: Error:
    Member not found: 'minStepBudget'.
```

### U3/U4 (phase inference, elapsed + descendant snapshot) — subprocess_timeout_test.dart

```text
  test/plugins/tdd/services/subprocess_timeout_test.dart:580:24: Error:
    The getter 'elapsed' isn't defined for the type 'ProcessTimeoutException'.
  test/plugins/tdd/services/subprocess_timeout_test.dart:618:26: Error:
    The getter 'descendantArgvs' isn't defined for the type
    'ProcessTimeoutException'.
```

### U7 (`StepResult.timeoutReceipt`) — step_runner_test.dart

```text
  test/plugins/tdd/services/step_runner_test.dart:383:21: Error:
    The getter 'timeoutReceipt' isn't defined for the type 'StepResult'.
```

### U8/U13 + scaled hand-down — run_driver_timeout_receipt_test.dart

```text
  Expected: contains 'timeout receipt:'
    Actual: 'zfa tdd run: feature 090-run-driver — 1 behavior(s)\n'
  Expected: contains 'WARNING: the explicit --timeout looks unsafe'
    Actual: 'zfa tdd run: feature 090-run-driver — 1 behavior(s)\n'
  Expected: contains '--timeout 25.0000'
    Actual: 'tdd make B-001 --feature 090-run-driver --project /tmp/tdd_fixture_BVJTZY
             --suite-baseline /tmp/tdd_fixture_BVJTZY/specs/090-run-driver/tdd/run-baseline.json'
  01:03 +0 -3: Some tests failed.
```

The third excerpt IS the issue's misfire signature: the make child's
argv carries NO `--timeout` at all (the fixed 10-minute internal default
in charge), the run prints no warning, and no receipt exists — the
diagnose-blind kill.

## M3 reds — live first-fail runs (this session, before the wiring)

### U10/U11/U9 — recert_scope_test.dart (library absent)

```text
  Failed to load "test/plugins/tdd/services/recert_scope_test.dart":
  test/plugins/tdd/services/recert_scope_test.dart: Error: Undefined name
    'RecertScope'. / Undefined name 'CorpusBaselineCache'.
```

### U12a/U12b/U12c — spec_1529_recert_wiring_test.dart (assertions, the wiring absent)

```text
  Failing tests:
    U12a: with importers present the guard runs ONE scoped invocation
      covering the own test and the neighbor — never the full suite
    U12b: a shared write outside the declared set fails closed — the
      full-suite guard runs unchanged
    U12c: an unprovable fingerprint fails closed — the full-suite guard
      runs unchanged
```

Isolated U12b excerpt (the guard never ran a scoped — nor any — suite
invocation):

```text
  Expected: <1>
    Actual: <0>
  suite invocations: []
```

U12d passed pre-wiring by design: it pins the EXISTING #741 zero-spawn
contract (a regression guard, not a new behaviour).

## Green state

Every behaviour above is green after its implementation landed; see
`tdd/verification.md` for the executed commands and counts.
