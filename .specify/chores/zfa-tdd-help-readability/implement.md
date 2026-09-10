# Chore Implementation: Improve readability of zfa tdd help text

- **Slug**: zfa-tdd-help-readability
- **Implemented**: 2026-09-10
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Added `usageLineLength: 100` to the `_CrashSafeCommandRunner` constructor call, enabling line wrapping for all CLI help text. This ensures command descriptions are wrapped at a consistent column width, preserving column alignment and improving readability.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/cli/cli_runner.dart` | modified | Added `usageLineLength` parameter to `_CrashSafeCommandRunner` constructor and forwarded it to `CommandRunner`. |

## Diff Highlights

```dart
// Before:
_CrashSafeCommandRunner(
    'zfa',
    'Zuraffa Code Generator - Clean Architecture for Flutter',
  )

// After:
_CrashSafeCommandRunner(
    'zfa',
    'Zuraffa Code Generator - Clean Architecture for Flutter',
    usageLineLength: 100,
  )
```

Also updated the class constructor to accept and forward the named parameter:

```dart
// Before:
_CrashSafeCommandRunner(super.executableName, super.description);

// After:
_CrashSafeCommandRunner(super.executableName, super.description, {super.usageLineLength});
```

## Verification

- Commands run: `dart analyze lib/src/cli/cli_runner.dart` → No issues found
- Commands run: `dart test test/cli/bug_1360_undeclared_option_crash_test.dart` → All tests passed
- Commands run: `dart test test/cli/` → All 225 tests passed
- Manual checks: `zfa tdd` help text now wraps long descriptions at 100 columns, maintaining column alignment. `zfa --help` also benefits from consistent wrapping.

## Deviations from Assessment

None. The implementation followed the proposed approach exactly.

## Follow-ups

- Consider adjusting `usageLineLength` to 80 if narrower terminals are common, but 100 appears to work well on typical modern terminals.
- The change affects all command help outputs globally, which is desirable for consistency.
- No further cleanup needed; the change is minimal and self-contained.