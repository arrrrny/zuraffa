**Template Version**: `zuraffa-1.0`

# Tasks: 1308-tdd-run-vacuous-guard-remedy

Dependency-ordered, MVP-first. T1-T4 are the behavioral MVP (the red-green
loop drives them); T5-T6 are the non-behavioral wiring (spec-kit artifacts,
docs) covered by `/speckit.implement`.

## 1. Messaging vocabulary (mvp)

- [x] **T1** (P1) `vacuous_guard.dart`: add `vacuousGuardFallbackRemedy`
  (the exact FR-001 remedy string), `vacuousGuardWarningToken` (the
  machine-greppable guard-only warning token),
  `contentCarriesVacuousGuardMarker` (the marker-presence predicate), and
  `vacuousGuardHandStepViolation` (the journal hand-step line builder).
  Traces: FR-005. Depends: —.

## 2. Gen-time warning (mvp)

- [x] **T2** (P1) `behavior_test_writer.dart`: when `write()` emits a UNIT
  test derived from the fallback path (contractShape == null) whose content
  is the guard-only shape WITHOUT the marker, print the loud warning naming
  the behavior id, the gap, the test path, and the FR-001 remedy. The test
  file is still written; the warning must not change the emitted content.
  Traces: FR-002. Depends: T1.
- [x] **T3** (P1) `run_driver_core.dart`: after a successful `gen` step,
  forward the child's warning-token lines into the run transcript.
  Traces: FR-003. Depends: T1.

## 3. Run/stop remedy + hand seam (mvp)

- [x] **T4** (P1) `run_driver_core.dart`: in `_driveBehavior`, add the
  vacuous-green make stop arm BEFORE the generic honest stop: resolve the
  generated test path (namespaced then legacy flat), read the content —
  marker absent → print the FR-001 remedy (replacing the generic resume
  line; summary keeps `stopped_at=<id>:make`); marker present → print the
  hand-step guidance (what to write + where) and stop with
  `stopped_at=<id>:hand`. `_finish` appends the hand-step violation line to
  the journal entry when the stop token is the hand seam.
  Traces: FR-001, FR-004. Depends: T1.

## 4. Verification

- [x] **T5** (P1) `tdd/verification.md`: record the red evidence, the green
  evidence, and the targeted test runs (analyze + changed-file tests only;
  no full suite on cloud agents). Depends: T2-T4.

## 5. Wiring / non-behavioral

- [x] **T6** (P2) Spec-kit artifacts (spec.md, plan.md, tasks.md,
  tdd/test-list.md, tdd/verification.md) committed with the code; PR body
  links issue #1308 and includes the vacuous-green stop-message demo.
  Depends: T5.
