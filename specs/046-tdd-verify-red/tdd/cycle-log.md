# Cycle Log: `zfa tdd verify-red`

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/` -> 104 passed, 2 failed
- commit: `0118a465`
- recorded: cycle 0, before any change

## Notes and deviations

- Pre-existing red at baseline (feature 044 tests, not caused by this
  feature): `verify_command_test.dart` NOT_ASSESSED expectation failure, and
  `gen_command_test.dart` PathNotFoundException from a temp-dir cwd restore
  after `verify_command_test` deletes its fixture. The loop must not start on
  top of these; fix or quarantine before cycle 1.

## Cycle 0 correction: baseline is green

- suite: `dart test test/plugins/tdd/` -> 106 passed, 0 failed, exit 0
- commit: `938a5aec`
- recorded: before cycle 1, re-verified at loop start

The two pre-existing 044 failures named in the original baseline note
(`verify_command_test.dart` NOT_ASSESSED expectation;
`gen_command_test.dart` temp-dir cwd restore) are fixed at `938a5aec`.
This entry corrects the record; the original note above is left untouched
because the log is append-only.

## Pre-cycle housekeeping (recorded before cycle 1)

- profile fix: `.specify/memory/tdd-profile.md` single-test command used
  `-P` which `dart test` interprets as `--preset` ("Undefined preset"),
  so every single-test invocation failed before reaching any test.
  Corrected to `dart test <file> --plain-name "<name>"` and a
  machine-readable Keys block added (same shape `zfa setup` writes).
- seed removal: the `zfa tdd gen B-003` demo pair committed in `938a5aec`
  (`test/tdd/b_003_test.dart`, `lib/tdd/b_003_subject.dart`, its
  `specs/044-test-tdd-generation/tdd/artifacts.json` record) was removed.
  Its registry record carried machine-local absolute paths
  (`/Users/.../zuraffa/...`) that resolve nowhere else, and its committed
  red test fails the full `dart test test` CI gate with no implementation
  to turn it green (`zfa tdd make` is a later feature). Nothing references
  the pair; the 046 test suite builds its own self-contained fixtures.

## Cycle 1: U15, U16 — CycleLogEntry 8-field contract + widened FailureClass

- behaviors: U15 (toMarkdown emits the 8 contract fields in fixed order),
  U16 (FailureClass gains skipped + runnerError, round-trips by name)
- test: `test/plugins/tdd/models/cycle_entry_test.dart` (new) — 4 new
  tests; 4 pre-existing tests updated for the widened constructor
  (sourceCriterion, testPath, timestamp are now required). Blast radius:
  `test/plugins/tdd/services/cycle_log_test.dart` call sites updated too.
- red: `dart test test/plugins/tdd/models/cycle_entry_test.dart` ->
  compile error (fields absent) -> minimal field stubs added -> assertion
  failure `Expected: <2> Actual: <1>` at the ordered-fields check:
  `"- criterion: FR-006" must appear after the previous contract field`
  (the stub toMarkdown did not emit criterion/test/at). That assertion
  failure is the recorded red for U15; U16's red was the same compile
  error phase (enum values absent).
- green: `toMarkdown()` now emits behavior, kind, classification,
  criterion, test, command, exit, at, output in the fixed order;
  `FailureClass` widened to six values. Suite
  `dart test test/plugins/tdd/` -> 110 passed, 0 failed.
- refactor: none needed — the rendering is one writeln cascade in the
  shape the contract pins.
- commit: (this commit)
