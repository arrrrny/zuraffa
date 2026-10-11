# Cycle Log

Feature: specs/1398-crash-safe-make-interrupt (issue #1398)
Branch: feat/1398-crash-safe-make-journal-interrupt
Driver: spec-kit TDD extension v1.1.2 (red-green-refactor, LLM-guided — the
subject under test is the zuraffa CLI itself, not a generated consumer
project; `zfa tdd run` cannot drive its own source).

## Cycle: U-marker (red)

- behavior: U-marker
- kind: red
- classification: compile-error
- criterion: FR-1, FR-5 (SC-6)
- test: test/plugins/tdd/bug_1398_marker_contract_test.dart
- command: `dart analyze test/plugins/tdd/bug_1398_marker_contract_test.dart`
- exit: 1
- captured: 3 analyzer errors — uri_does_not_exist
  ('package:zuraffa/src/plugins/tdd/services/make_interrupt.dart'),
  undefined_class 'MakeInterruptMarker' (x2). The unit tier is red for the
  right reason: the marker service does not exist.
- at: 2026-09-16T00:00:00.000Z

## Cycle: A-adopt (red — pre-implementation suite run)

- behavior: A-adopt
- kind: red
- classification: assertionFailure (5 of 6 e2e tests failed; U5 vacuous-pass
  pre-implementation, strengthened and re-driven below)
- criterion: AC-1, AC-2, AC-3 (SC-1..SC-5)
- test: test/plugins/tdd/bug_1398_make_interrupt_recovery_test.dart
- command: `dart test test/plugins/tdd/bug_1398_make_interrupt_recovery_test.dart`
- exit: 1
- captured (the honest reds):
  - A1 SIGKILL: `Expected: not null / Actual: <null> / a killed make leaves
    the interrupt marker behind` — the real make subprocess was killed after
    the subject mutation landed; the crash left NO journal trace. This is
    issue #1398's root cause reproduced: the crime scene carries no evidence
    distinguishing the driver's own half-made work from a hand-edit.
  - A2 hand-edit: pre-fix run failed for the WRONG reason (exit 0 — the
    red-basis drift took the #1162 hand-implementation fail-open). Test
    corrected to the #1331 B8b green-basis shape (stale green evidence
    binding the stub hash seeded first); the corrected red is the refusal
    class itself, green-gated post-implementation.
  - A3 marker+placeholder: refusal fired (exit non-zero, no green entry) but
    `the refusal exit cleared the marker (no stale license)` — Expected null,
    Actual {marker}. RED: no marker hygiene exists.
  - U6/U7 driver: `zfa tdd run: step failed — behavior=U-001 step=make
    outcome=adopted-interrupted ... result=stopped stopped_at=U-001:make` —
    the driver does not know the token; StepRunner grades it failed. RED for
    FR-6.
- at: 2026-09-16T00:00:00.000Z

## Cycle: U-marker (green)

- behavior: U-marker
- kind: green
- criterion: FR-1, FR-5 (SC-6)
- test: test/plugins/tdd/bug_1398_marker_contract_test.dart
- command: `dart test test/plugins/tdd/bug_1398_marker_contract_test.dart`
- exit: 0
- captured: `00:02 +4: All tests passed!` — U1 (atomic behavior-named
  in-progress record, no tmp residue), U2 (same-behavior pendingFor), U3
  (missing/corrupt/wrong-shape/foreign-behavior/non-pending all read as
  absent — fail closed), U4 (clear idempotent, never throws on missing).
- generation steps: MakeInterruptMarker service (tmp + fsync + rename write;
  schema/status/behavior-gated read; best-effort clear + clearSync for the
  summary funnel).
- at: 2026-09-16T00:00:00.000Z

## Cycle: A-adopt (green)

- behavior: A-adopt
- kind: green
- criterion: AC-1, AC-2, AC-3 (SC-1..SC-6)
- test: test/plugins/tdd/bug_1398_make_interrupt_recovery_test.dart
- command: `dart test test/plugins/tdd/bug_1398_make_interrupt_recovery_test.dart --preset=all`
- exit: 0
- captured: `01:08 +10: All tests passed!` (with the unit file: 10/10).
  - A1 SIGKILL: the real `zfa tdd make` subprocess was SIGKILLed after the
    fake pipeline's func step mutated the subject (kill window verified by
    polling the subject bytes); the crash left the marker
    (`behavior: A1, status: in-progress`) and NO green evidence (SC-1); the
    resumed make exited 0 with `outcome=adopted-interrupted`, the green
    evidence binds the CURRENT subject hash, and the marker was consumed by
    the adoption exit (SC-2).
  - A2 hand-edit: the identical green-basis drift WITHOUT a marker still
    refuses `outcome=subject-drift`; exactly one green entry (the seeded
    stub-hash certification) remains and no entry ever binds the
    hand-edited hash (SC-3).
  - A3 marker+placeholder: the crash marker does not legitimize the
    born-green placeholder — refusal stands (`--> fix:`), no new green
    entry, and the graceful refusal consumed the marker (SC-4).
  - U5 hygiene: a pre-seeded crash-residue marker is consumed by the
    not-certified-red refusal exit — no stale license (SC-6).
  - U6/U7 driver: the run driver grades `adopted-interrupted` a terminal
    make success — `result=complete` for the exit-0 shape, and the
    exit-code-disagreement shape records the driver's own green evidence
    naming the #1398 transition (bug #986 pattern) (SC-5).
- generation steps: make read-before-begin + interrupt adoption arm
  (placeholder-gated) + MakeOutcome.adoptedInterrupted + _printSummary
  clearSync funnel + StepRunner success token + run-driver bug-#986 arm.
- at: 2026-09-16T00:00:00.000Z

## Cycle: R-guard (green — regression sweep, no new behavior)

- behavior: R-guard
- kind: green
- criterion: FR-7 (no regression in the preserved classes)
- test: existing suites run against the changed code, each compared with the
  SAME suite on clean master (git stash) — identical results.
- command: `dart test --preset=all <suite>`
- exit: 0
- captured:
  - bug_1331_make_adopted_re_drive_test.dart: 8/8 pass (the #1331 adoption,
    B7/B7b driver acceptance, B8a/B8b/B8c refusals, B9/B10 prescriptions).
  - make_command_1036_test.dart: identical to master — 1 pre-existing
    failure (A-1036a; the #1587 build-skip drift), rest pass. UNRELATED:
    fails identically with the changes stashed.
  - bug_828_cycle_log_evidence_integrity_test.dart: pass (identical).
  - bug_1324_resume_stale_artifacts_wedge_test.dart +
    bug_1345_placeholder_re_drive_test.dart +
    bug_1430_refresh_evidence_test.dart: +25 -4, the SAME 4 failures on
    master (1324 B1; 1345 B1+B2, B7; 1430 U-1430-2) — all pre-existing,
    UNRELATED.
  - make_command_test.dart (spec 047 main suite): +30 -10, identical on
    master — all 10 pre-existing, UNRELATED.
- at: 2026-09-16T00:00:00.000Z

