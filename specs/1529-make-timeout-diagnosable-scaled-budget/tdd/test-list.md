# Test List — 1529 make timeout: receipt, scaled budget, trimmed re-certification

**Feature**: 1529-make-timeout-diagnosable-scaled-budget
**Loop**: outer (unit lane — pure helpers + driver/step-contract wiring)
**Runner profile**: `dart test` (fast tier; no Flutter host required)

## Outer loop: unit behaviors

- U1 — `scaledStepBudget` derives `max(25 min, 4 x baseline)`: a 9-minute
  baseline yields 36 minutes; a 4-minute baseline yields the 25-minute
  floor; a null baseline yields the floor.
  **Type**: unit — `test/plugins/tdd/services/subprocess_timeout_test.dart`
- U2 — `scaledStepBudget` honors an explicit budget: the explicit value
  wins over every derivation; null explicit + null baseline = floor.
  **Type**: unit — `test/plugins/tdd/services/subprocess_timeout_test.dart`
- U3 — `inferTimeoutPhase` grades `running` when a descendant argv names
  a test runner (`flutter_tester`, `dart ... test`, `flutter ... test`),
  `compiling` for kernel/build signals (`frontend_server`, `kernel`,
  `build_runner`, `dart compile`), `unknown` when no signal, and always
  returns the evidence it used; the process-tree evidence outranks the
  output markers.
  **Type**: unit — `test/plugins/tdd/services/subprocess_timeout_test.dart`
- U4 — `runTimed`'s timeout exception carries the ACTUAL elapsed wall
  time (measured, ≥ the deadline within tolerance) and the descendant
  snapshot (empty list when the platform probe fails — never throws).
  **Type**: unit — `test/plugins/tdd/services/subprocess_timeout_test.dart`
- U5 — `StepTimeoutReceipt` JSON round-trips the v1 fields (schema,
  behavior, step, argv, elapsed, deadline, phase, evidence, output tail,
  capturedAt) and `write()` lands the file at
  `specs/<feature>/tdd/make.<behaviorId>.timeout.json`.
  **Type**: unit — `test/plugins/tdd/services/step_timeout_receipt_test.dart` (new)
- U6 — the receipt write is best-effort: an unwritable target directory
  surfaces a failed-write note from the writer API result without
  throwing.
  **Type**: unit — `test/plugins/tdd/services/step_timeout_receipt_test.dart` (new)
- U7 — `StepRunner.run` maps a `ProcessTimeoutException` to the
  `runner-error` StepResult AND populates `timeoutReceipt` (argv,
  elapsed, deadline, phase, output tail); non-timeout paths leave it
  null.
  **Type**: unit — `test/plugins/tdd/services/step_runner_test.dart`
- U8 — the run driver, on a make step killed at the deadline, writes the
  receipt into the feature tdd dir and names its path in the failure
  report; the run result stays `runner-error`.
  **Type**: acceptance —
  `test/plugins/tdd/commands/run_driver_timeout_receipt_test.dart` (new)
- U9 — the baseline caches persist and read an optional `durationMs`
  (feature-local + corpus-wide); old files without the key read as
  null.
  **Type**: unit — `test/plugins/tdd/run_baseline_cache_test.dart`
- U10 — `recertScopeFor` returns exactly {own test, importer test} for a
  fixture tree that also holds an unrelated test, follows relative and
  self-package (`package:<self>/...`) imports, follows `export` and
  `part`/`part of` links transitively, and yields the full-tree signal
  when every test is in scope.
  **Type**: unit — `test/plugins/tdd/services/recert_scope_test.dart` (new)
- U11 — `makeRecertDecision` (pure): scoped command only when the
  fingerprint exists AND the write set is declared-only; the
  shared-write, no-fingerprint, and no-suite-template conditions all
  select the existing full-suite path; the scope==whole-tree condition
  selects the full suite.
  **Type**: unit — `test/plugins/tdd/services/recert_scope_test.dart` (new)
- U12 — the driver-path guard upgrade: with a cached full-suite baseline
  and an empty importer set, the guard certifies from the post-
  generation transcript with ZERO extra spawns (the small-suite
  contract); with importers present the scoped run is appended to the
  suite template and its failures are diffed with the #731 tolerance
  against the cached baseline.
  **Type**: unit — `test/plugins/tdd/services/recert_scope_test.dart` (new)
- U13 — the loud budget warning: an explicit `--timeout` below the
  projected make cost (`4 x measured baseline`) makes the driver print a
  multi-line warning naming both numbers BEFORE the first step spawns,
  while the honored budget stays the explicit value (spec US2
  acceptance scenario 2 / SC-4).
  **Type**: acceptance —
  `test/plugins/tdd/commands/run_driver_timeout_receipt_test.dart` (new)

## Non-behavioural tasks (no red-green loop)

- N1 — `dart format` over the touched files; `dart analyze` clean on the
  changed set; existing suites for the touched surfaces stay green.
- N2 — spec artifacts (spec/plan/tasks + tdd/verification) committed
  under `specs/1529-make-timeout-diagnosable-scaled-budget/`.

## Red evidence protocol

Each U-behavior's first failing run is recorded in
`tdd/verification.md` (test name, red assertion output excerpt) before
the green implementation lands in the same commit series.
