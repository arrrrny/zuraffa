Added `usageLineLength: 100` to the `_CrashSafeCommandRunner` constructor call, enabling line wrapping for all CLI help text. This ensures command descriptions are wrapped at a consistent column width, preserving column alignment and improving readability.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/cli/cli_runner.dart` | modified | Added `usageLineLength` parameter to `_CrashSafeCommandRunner` constructor and forwarded it to `CommandRunner`. |

## Verification

- Commands run: `dart analyze lib/src/cli/cli_runner.dart` → No issues found
- Commands run: `dart test test/cli/bug_1360_undeclared_option_crash_test.dart` → All tests passed
- Commands run: `dart test test/cli/` → All 225 tests passed
- Manual checks: `zfa tdd` help text now wraps long descriptions at 100 columns, maintaining column alignment. `zfa --help` also benefits from consistent wrapping.

Assessment: .specify/chores/zfa-tdd-help-readability/assessment.md

Closes #1452