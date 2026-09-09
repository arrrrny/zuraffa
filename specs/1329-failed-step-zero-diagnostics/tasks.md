**Template Version**: `zuraffa-1.0`

# Tasks: 1329-failed-step-zero-diagnostics

Dependency-ordered, MVP-first. T1-T4 are the behavioral MVP (the
red-green loop drives them); T5-T6 are the non-behavioral wiring
(schema, artifacts) covered by `/speckit.implement`.

## 1. Evidence plumbing (mvp)

- [x] **T1** (P1) `step_runner.dart`: add the spawned `command` field to
  `StepResult` — the argv the runner actually executed, joined for
  display, captured once where the argv is built and carried by every
  construction site (success, spawn-failure, timeout). Traces: FR-001.
  Depends: —.
- [x] **T2** (P1) `cycle_entry.dart`: add the `error` value to
  `CycleEntryKind` (label `error`), and the optional `outcome` field to
  `CycleLogEntry` rendered as an `- outcome:` line only when set (outside
  the chain-hash payload). Red/green/refactor rendering stays
  byte-compatible (U10). Traces: FR-001, FR-003. Depends: —.

## 2. Driver recording (mvp)

- [x] **T3** (P1) `run_driver_core.dart`: in `_driveBehavior`, add the
  failure-detail capture + cycle-log `error` entry append to the honest
  stop arm (the spawned command, exit code, and the 200-line output tail
  with a truncation marker — never a gate: a failed append is reported,
  not fatal), and the same shape to the pre-spawn `StateError` arm
  (`outcome=runner-error`, exit -1, the resolution message as output, no
  spawned command). Carry the detail to `_finish` via the private
  instance field (reset per drive; the stream-context pattern). The
  append must not change the stop's result, stoppedAt, or exit code.
  Traces: FR-001, FR-003, FR-004, FR-005. Depends: T1, T2.
- [x] **T4** (P1) `run_driver_core.dart` `_finish`: when the drive
  stopped on a failed step, add the machine-greppable
  `step_error=<behavior>:<step> outcome=<o> exit=<n>` violations line and
  the structured `error` object to the lane journal entry. Traces:
  FR-002. Depends: T3.

## 3. Journal schema (wiring)

- [x] **T5** (P2) `journal.dart`: add the `JournalStepError` model class
  (behavior, step, outcome, exit_code, command, output) with
  `toJson`/`fromJson`; wire the optional `error` field through
  `JournalEntry` (`toJson`/`fromJson`), `_entrySchema()` (the declared
  optional object property) and `validateEntry` (the same walk the tests
  use). Traces: FR-002. Depends: T4.

## 4. Verification

- [x] **T6** (P1) `tdd/verification.md`: record the red evidence, the
  green evidence, and the targeted test runs (analyze + changed-file
  tests only; no full suite on cloud agents). Depends: T1-T5.

## 5. Wiring / non-behavioral

- [x] **T7** (P2) Spec-kit artifacts (spec.md, plan.md, tasks.md,
  tdd/test-list.md, tdd/verification.md) committed with the fix; the
  fixture's fake zfa gains the ADDITIVE `flood` gen outcome token for the
  truncation proof. Traces: FR-001. Depends: T3.
