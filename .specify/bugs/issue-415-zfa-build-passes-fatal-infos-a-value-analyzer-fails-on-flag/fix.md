# Bug Fix: zfa build: passes --fatal-infos a value → analyzer fails on flag → false 'no errors'

- **Slug**: issue-415-zfa-build-passes-fatal-infos-a-value-analyzer-fails-on-flag
- **Fixed**: 2026-08-22T19:50:00+00:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

The post-build `dart analyze` guard in `BuildCommand.verifyAnalyzeOrFail` invoked
`dart analyze --fatal-infos=false lib`. `--fatal-infos` is a boolean flag and
rejects the `=false` value (`exit 64`, "Flag option should not be given a
value"), so the analyzer aborted before analyzing and produced empty stdout.
The guard then saw no `error` lines and falsely reported success. Removed the
invalid flag (info is non-fatal by default), restoring real error detection.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/commands/build_command.dart` | modified | Removed `'--fatal-infos=false'` from the `dart analyze` arg list; updated the explanatory comment. |
| `test/commands/build_command_unit_test.dart` | added test | New `verifyAnalyzeOrFail` group asserting the guard runs `dart analyze lib` and reports no errors on the warning/info-only lib. |

## Diff Highlights

```dart
final result = await Process.run('dart', [
  'analyze',
-  '--fatal-infos=false',
  'lib',
], workingDirectory: root);
```

## Tests Added or Updated

- `test/commands/build_command_unit_test.dart` — group `verifyAnalyzeOrFail (issue #415 ...)`: spawns the fixed analyzer invocation on the package root and expects `isTrue`.

## Local Verification

- Commands run:
  - `dart analyze --fatal-infos=false lib` → `exit 64` (proves the original bug condition).
  - `dart analyze lib` → `exit 0/2` with 12 info/warning issues, **no `error` lines** (proves the fixed invocation works).
  - `dart test test/commands/build_command_unit_test.dart --name "verifyAnalyzeOrFail"` → `All tests passed!` (exit 0).

## Deviations from Assessment

None.

## Follow-ups

- None. The existing `analyzeReportsError` tests (#395) continue to guard the error-detection parser.
