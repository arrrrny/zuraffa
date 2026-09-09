# TDD Cycle Log — Spec 1360

## RED (2026-09-09)
- `dart test test/cli/bug_1360_undeclared_option_crash_test.dart` →
  `+2 -2` (B1/B4 red on the crash; B2/B3 guards green as declared).
- Committed as certified red before the implementation.

## GREEN (2026-09-09)
- `_CrashSafeCommandRunner.parse` override: TypeError → recover the
  ArgParserException → defensive chain walk → deepest command's
  usageException. `+4 All tests passed!`; cli pin `+20 All tests
  passed!`; analyze clean.
- Live probe: `dart run bin/zfa.dart simulate run --world=v3` →
  `❌ Could not find an option named "--world".` + usage (no crash).
