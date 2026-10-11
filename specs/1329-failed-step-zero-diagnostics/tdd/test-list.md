# Test List: 1329-failed-step-zero-diagnostics

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1329-1 | a failing gen step (outcome=error, exit 1) appends ONE cycle-log error entry carrying the spawned command, the exit code, and the child's output tail (`zfa tdd gen: boom`); the stop's result/stopped_at/exit code are unchanged | FR-001, SC-1 | GREEN |
| U-1329-2 | the lane journal entry for the failed step carries the structured error object (behavior, step, outcome, exit_code, command, output) and the `step_error=` violations line beside `stopped_at=`, and validates against the generated schema walk | FR-002, SC-2 | GREEN |
| U-1329-3 | the error entry never satisfies red or green evidence: after the failure the behavior's reconciled state stays pending and the retry re-drives gen (and the full cycle completes) | FR-003 | GREEN |
| U-1329-4 | a successful retry appends its own entries and preserves the previous failure's diagnostics in both cycle-log.md and journal.json (append order: failure entry precedes the retry's entries) | FR-003, SC-3 | GREEN |
| U-1329-5 | output longer than 200 lines is truncated to the LAST 200 lines with an honest truncation marker; the marker names the dropped count; the last error line survives | FR-001 | GREEN |
| U-1329-6 | a failing make step records the make spawn's command and outcome token (`- outcome: crashed`); the pre-spawn runner-error arm records exit -1 with the resolution message and no spawned command | FR-001, FR-004 | GREEN |
| U-1329-7 | backward compatibility: a fully green run records no error entries and no journal error object; existing deferral/skip/block evidence is byte-identical (run_command_test + two-cycle + unified journal suites stay green) | FR-004, SC-4 | GREEN |

## Layer contracts

```yaml
# fr: FR-001
step_runner.dart: StepResult carries the spawned command line (captured where the argv is built)
# fr: FR-001, FR-003
cycle_entry.dart: CycleEntryKind.error exists; CycleLogEntry renders the optional - outcome: line; red/green/refactor rendering byte-compatible
# fr: FR-001, FR-003, FR-004, FR-005
run_driver_core.dart: the honest-stop and pre-spawn arms append the error cycle entry and stage the failure detail for _finish; a failed append is reported, never fatal
# fr: FR-002
journal.dart: JournalEntry carries the optional structured error object; the generated schema declares it; validateEntry checks it
```

## Key entities

```yaml
StepResult: one step invocation's machine outcome; now names the spawned command
CycleLogEntry: one cycle-log row; the error kind records failed-step evidence
JournalStepError: the journal's structured failed-step evidence (behavior, step, outcome, exit_code, command, output)
RunDriverCore: drives the two-cycle runner; owns the error-outcome recording path
```

## External dependencies

(none — pure-Dart recording layer; the driver tests use the scripted fake
zfa binary from TddFixture)
