## Summary

`zfa build`'s post-build `dart analyze` guard (`BuildCommand.verifyAnalyzeOrFail`) invoked `dart analyze --fatal-infos=false lib`. `--fatal-infos` is a boolean flag and **rejects** the `=false` value, so the analyzer aborted at flag-parse (`exit 64`, "Flag option should not be given a value") and produced **empty stdout**. The guard then saw no `error` lines and falsely reported "✅ dart analyze: no errors", masking genuinely broken generated code.

Removed the invalid flag. Info-level issues are non-fatal by default, which is exactly the documented guard contract (only `error` severity fails the build). Error detection is preserved via the existing `analyzeReportsError` parser.

## Changes

| File | Change |
|------|--------|
| `lib/src/commands/build_command.dart` | Removed `'--fatal-infos=false'` from the `dart analyze` arg list; updated the explanatory comment. |
| `test/commands/build_command_unit_test.dart` | Added `verifyAnalyzeOrFail` regression group asserting the guard runs `dart analyze lib` and reports no errors on the warning/info-only lib. |

## Local Verification

- `dart analyze --fatal-infos=false lib` → `exit 64` (proves the original bug condition).
- `dart analyze lib` → 12 info/warning issues, **no `error` lines** (proves the fixed invocation works).
- `dart test test/commands/build_command_unit_test.dart --name "verifyAnalyzeOrFail"` → **All tests passed!**

Assessment: `.specify/bugs/issue-415-zfa-build-passes-fatal-infos-a-value-analyzer-fails-on-flag/assessment.md`

Closes #415
