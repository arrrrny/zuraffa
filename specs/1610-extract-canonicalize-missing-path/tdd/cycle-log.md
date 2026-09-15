# Cycle Log: Extract canonicalizeMissingPath — documented precondition + direct walk-up test (chore #1610)

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/commands/view_command_test.dart
  test/plugins/tdd/wire_command_test.dart
  test/plugins/tdd/commands/func_command_test.dart` (default preset) →
  **10 passed** — the +10 is func_command_test.dart ONLY: view and wire
  carry `@Tags(['slow'])` and the default preset excludes the slow tag, so
  those two files ran ZERO tests (a load-time "Does not exist" misread was
  ruled out: the wire file lives at `test/plugins/tdd/wire_command_test.dart`,
  NOT under `commands/` — path corrected and re-run)
- suite (corrected tiers): `dart test --preset=all
  test/plugins/tdd/commands/view_command_test.dart` → **15 passed, 0 failed**;
  `dart test --preset=all test/plugins/tdd/wire_command_test.dart` →
  **16 passed, 0 failed**; `dart test
  test/plugins/tdd/commands/func_command_test.dart` → **10 passed, 0 failed**
- commit: `f220b6a3`
- recorded: cycle 0, before any change — suite_baseline: green
- note: the slow-tier requirement for the pin suites is recorded in
  tdd/test-list.md "Verification commands" so verify runs the pins under
  `--preset=all`
