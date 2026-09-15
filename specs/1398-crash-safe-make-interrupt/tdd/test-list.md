# Test List: crash-safe make — journal the interrupt, adopt on resume

```yaml
---
feature: 1398-crash-safe-make-interrupt
loop: inside-out # tool-internal fix: no user-visible surface of its own; the
                 # "acceptance" row drives a real zfa tdd make subprocess
profile: .specify/memory/tdd-profile.md
spec_criteria: 7 # SC-1..SC-7 in spec.md
planned_at: (working tree)
updated_at: (working tree)
suite_baseline: unknown # full suite not run on this branch yet; targeted suites run per phase
---
```

## Outer loop: acceptance behaviors

One per acceptance criterion family in `spec.md`. A1 drives a REAL
`zfa tdd make` subprocess end to end (spawn → SIGKILL → resume) — the only
honest proof of the crash class.

| id  | behavior                                                                                        | traces        | kind    | state   | test                                                                        |
| --- | ---------------------------------------------------------------------------------------------- | ------------- | ------- | ------- | --------------------------------------------------------------------------- |
| A1  | A make SIGKILLed mid-flight leaves the interrupt marker with no green evidence; the resumed make adopts (`adopted-interrupted`, exit 0, current-hash green evidence) | AC-1, AC-2, SC-1, SC-2 | example | PENDING | `test/plugins/tdd/bug_1398_make_interrupt_recovery_test.dart::killed make recovers on resume` |
| A2  | The identical drift WITHOUT a crash marker keeps the subject-drift refusal (dishonest class)    | AC-3, SC-3    | example | PENDING | `test/plugins/tdd/bug_1398_make_interrupt_recovery_test.dart::hand edit still refuses` |
| A3  | A crash marker never legitimizes a born-green placeholder subject                               | AC-3, SC-4    | example | PENDING | `test/plugins/tdd/bug_1398_make_interrupt_recovery_test.dart::marker plus placeholder refuses` |

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/services/make_interrupt.dart` (marker service)

| id  | behavior                                                                                | traces     | kind    | state   | test                                                                             |
| --- | --------------------------------------------------------------------------------------- | ---------- | ------- | ------- | -------------------------------------------------------------------------------- |
| U1  | begin writes an atomic, behavior-named in-progress record                               | FR-1       | example | PENDING | `...bug_1398_marker_contract_test.dart::begin writes marker`                      |
| U2  | pendingFor reads a same-behavior in-progress record                                     | FR-2       | example | PENDING | `...::pendingFor reads same behavior`                                             |
| U3  | pendingFor treats missing / corrupt / foreign-behavior markers as absent (fail closed)  | FR-5, SC-6 | example | PENDING | `...::pendingFor fails closed`                                                    |
| U4  | clear removes the marker idempotently and never throws on a missing file                | FR-5, SC-6 | example | PENDING | `...::clear is idempotent`                                                        |

### `lib/src/plugins/tdd/commands/make_command.dart` + `run_driver_core.dart` (loop integration)

| id  | behavior                                                                                                    | traces        | kind    | state   | test                                                                        |
| --- | ----------------------------------------------------------------------------------------------------------- | ------------- | ------- | ------- | --------------------------------------------------------------------------- |
| U5  | A graceful make exit (green path, fake zfa driver) clears the marker — no stale license                     | FR-5, SC-6    | example | PENDING | `...bug_1398_make_interrupt_recovery_test.dart::graceful exit clears marker` |
| U6  | The driver grades `adopted-interrupted` a terminal make success and completes the run                       | FR-6, SC-5    | example | PENDING | `...bug_1398_make_interrupt_recovery_test.dart::driver accepts token`        |
| U7  | The driver records the green evidence itself when the token's exit code disagrees (bug #986 pattern, #1398 messaging) | FR-6 | example | PENDING | `...::driver records evidence on exit-code disagreement`                     |

## Notes

- R-guard (tasks T008/T011) is a regression sweep, not a new behavior: the
  existing `bug_1331_make_adopted_re_drive_test.dart` and
  `make_command_1036_test.dart` suites ARE the preserved-class evidence
  (FR-7) and run unchanged.
- Every red must be recorded in `tdd/cycle-log.md` with the captured failure
  before the matching green.
