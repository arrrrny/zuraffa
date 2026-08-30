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
