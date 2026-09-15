# Tasks: crash-safe make — journal the interrupt, adopt on resume

**Feature**: specs/1398-crash-safe-make-interrupt · **Issue**: #1398 · **Plan**: [plan.md](./plan.md)

Tests are mandatory and precede implementation ([tdd/test-list.md](./tdd/test-list.md), derived per the TDD extension). Every behavior below traces to an AC in spec.md.

## 1. Marker service (foundation)

- [ ] T001 Write the failing tests for the `MakeInterruptMarker` contract: begin writes an atomic behavior-named record; `pendingFor` returns same-behavior in-progress records only; corrupt / foreign-behavior / missing files read as absent (fail closed); clear removes idempotently; a clear on a missing marker never throws (FR-1, FR-5; SC-6) `[behavior: U-marker]`
- [ ] T002 Implement `services/make_interrupt.dart` to make U-marker green: tmp + fsync + rename write, schema/feature/behavior/pid/at/status payload, best-effort clear (FR-1, FR-5) `[behavior: U-marker]`

## 2. Make command integration (the recovery)

- [ ] T003 Write the failing integration tests: (a) SIGKILL a real make mid-flight after the subject mutation → marker survives, no green evidence (SC-1); (b) resume make → `outcome=adopted-interrupted`, exit 0, green evidence binding the current subject hash (SC-2); (c) identical drift WITHOUT a marker → `subject-drift` refusal, no green entry (SC-3); (d) marker + born-green placeholder → refusal stands (SC-4); (e) graceful exits clear the marker (SC-6) `[behavior: A-adopt]`
- [ ] T004 Implement the make integration to make A-adopt green: read-before-begin, the interrupt adoption arm in front of the existing already-green arms (placeholder-gated), `MakeOutcome.adoptedInterrupted`, `_printSummary` clears the marker on every terminal path (FR-2, FR-3, FR-4, FR-5) `[behavior: A-adopt]`
- [ ] T005 Add `MakeOutcome.adoptedInterrupted('adopted-interrupted')` with the #1398 documentation contract (FR-3, FR-6) `[behavior: A-adopt]`

## 3. Driver + step contract (loop acceptance)

- [ ] T006 Write the failing driver-level test: a make reporting `outcome=adopted-interrupted` (exit 0 and the exit-code-disagreement shape) is a terminal make success — the run completes and the driver-recorded evidence names the transition (SC-5; FR-6) `[behavior: U-driver]`
- [ ] T007 Implement: StepRunner make success set gains `adopted-interrupted`; the run driver's bug-#986 arm recognizes the token with #1398 messaging (FR-6) `[behavior: U-driver]`

## 4. Regression guard (no-widening)

- [ ] T008 Verify the preserved classes end-to-end: #694 skip, #1331 tombstone adoption, #1345 placeholder re-entry, #1036 refusal, #1430 refresh acceptance — run the existing `bug_1331_make_adopted_re_drive_test.dart` and `make_command_1036_test.dart` suites against the changed code and confirm zero behavior change (FR-7) `[behavior: R-guard]`

## 5. Artifacts + verification

- [ ] T009 `/speckit.analyze` — cross-artifact consistency sweep (spec ↔ plan ↔ tasks ↔ test-list); fix drift `[behavior: R-guard]`
- [ ] T010 `/speckit.tdd.verify` — audit test-first evidence, red-phase evidence, test-smell rubric, acceptance-criteria coverage; write `tdd/verification.md` from the REAL run `[behavior: R-guard]`
- [ ] T011 `dart analyze` clean on changed files; `dart format .` zero remaining diffs; targeted test report with actual pass/fail counts (SC-7) `[behavior: R-guard]`
