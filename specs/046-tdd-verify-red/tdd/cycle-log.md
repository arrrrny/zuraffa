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
