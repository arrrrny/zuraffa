# Verification: 1329-failed-step-zero-diagnostics

## Test-first evidence (red → green)

| behavior | red evidence | green evidence |
| -------- | ------------ | -------------- |
| U-1329-1 (FR-001 gen error entry) | RED: driver run vs pristine HEAD — cycle-log had NO error entry (`Expected: contains ('B-001', 'error') / Actual: ['red','green']`-family failures; the failure path wrote nothing) | GREEN: `## Cycle: B-001 (error)` with `- outcome: error`, `- command: .../zfa tdd gen B-001 --feature 1329-diagnostics --project ...`, `- exit: 1`, output block `zfa tdd gen: boom`; stop contract unchanged (`stopped_at=B-001:gen`, exit non-zero) |
| U-1329-2 (FR-002 journal error detail) | RED: journal entry carried no `error` object and no `step_error=` violations line | GREEN: structured `error` object (`behavior: B-001, step: gen, outcome: error, exit_code: 1, command, output`) + `step_error=B-001:gen outcome=error exit=1` violations line beside `stopped_at=`; `JournalSchema.validateEntry` returns empty |
| U-1329-3 (FR-003 error ≠ evidence) | GREEN by construction on the red run (state stayed pending) — guarded by the kind choice (D1) | GREEN: retry re-drives gen — invocations `gen, gen, verify-red, make, refactor`, state `done` |
| U-1329-4 (FR-003 survive retry) | RED: cycle-log kinds after a successful retry were `['red','green']` — the failure entry was never written | GREEN: kinds `['error','red','green']` in append order; journal keeps BOTH lane entries — first (failed, `gate_state: red`, error object), last (retry, `gate_state: green`, no error); `zfa tdd gen: boom` survives verbatim |
| U-1329-5 (FR-001 truncation) | RED: `PathNotFoundException: .../tdd/cycle-log.md` — the failure wrote NO cycle log at all (the zero-diagnostics gap itself) | GREEN: 251 captured lines → the LAST 200 with the marker (`truncated` / `200 of 251`); noise lines 1-51 dropped (line-anchored), 52-250 + the final error line kept; the journal error object carries the same tail |
| U-1329-6 (FR-004 make + runner-error shapes) | RED: no error entry for a failing make / a spawn failure | GREEN: make crash records `- outcome: crashed`, the `tdd make B-001` spawn, exit 1; a missing zfa binary records `- exit: -1`, the `spawn failed` message, journal `outcome: runner-error, exit_code: -1`; the certified red evidence is untouched |
| U-1329-7 (FR-004 backward compat) | — (guard) | GREEN: a fully green run records no error entries and no journal error object; `run_command_test.dart` 49/49 unchanged |

## Test runs (cloud-agent scope: changed files only — no full suite)

```text
dart analyze <all changed dart files + the new test file>      → No issues found!
dart format --set-exit-if-changed <changed files>              → 0 changed (exit 0 — the CI format gate)
dart test --preset=all test/plugins/tdd/bug_1329_step_failure_diagnostics_test.dart → 7/7 pass
dart test --preset=all test/plugins/tdd/run_command_test.dart  → 49/49 pass (driver backward compat)
dart test --preset=all test/plugins/tdd/two_cycle_run_commands_test.dart
                        test/plugins/tdd/unified_journal_commands_test.dart
                        test/plugins/tdd/bug_1259_vacuous_green_test.dart → 40/40 pass
dart test --preset=all test/plugins/tdd/issue_1308_vacuous_guard_remedy_driver_test.dart → 4/4 pass
dart test --preset=all test/plugins/tdd/models/cycle_entry_test.dart
                        test/plugins/tdd/models/refactor_action_test.dart
                        test/plugins/tdd/services/cycle_log_test.dart
                        test/plugins/tdd/services/subprocess_timeout_test.dart → 45/45 pass
```

Kernel-cache hygiene: `.dart_tool/test/` and `$TMPDIR/dart_test.kernel.*`
removed before and after every targeted run; `df -h .` after the battery:
8.2G free of 9.9G (83%).

Pre-existing, unrelated failures on pristine HEAD (reproduced with the
changes STASHED — NOT introduced by this feature):

- `test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart`:
  7 pass / 4 fail on pristine HEAD and 7/4 with the changes — the
  failing set is byte-identical (diffed by name):
  `zfa tdd doctor ... a pending journal is reported as an interrupted
  transaction ...`, `... doctor exits 0 on consistent stores`,
  `... doctor reports a green claim without evidence as drift ...`,
  and `... doctor detects a tampered hash chain and prescribes a fix`.
  Environment-dependent doctor-spawn failures on this machine.

## Coverage notes

- The honest-stop arm is exercised for `gen` (outcome=error), `make`
  (outcome=crashed), and the spawn-failure runner-error (exit -1) — the
  recording path is shared by every step the driver spawns (the named
  deferral/skip/block arms are intentionally NOT recorded — AC-4).
- The pre-spawn `StateError` arm (entrypoint resolution failure) records
  through the SAME `_recordStepFailure` helper (outcome=runner-error,
  exit -1, the resolution message, no spawned command). It is not
  driver-executable in-process (the entrypoint always resolves in a test
  context) — covered by construction via the shared helper, not by a
  dedicated execution.
- The journal schema walk (`JournalSchema.validateEntry`) validates the
  written entry with the new `error` object — the shipped schema and the
  writer cannot drift (the schema is generated from the model, #1111).
