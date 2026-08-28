# Bug Fix: zfa make crashes with JIT FFI error instead of friendly validation messages

- **Slug**: issue-249-bug-zfa-make-crashes-with-jit-ffi-error-instead-of-friendly
- **Fixed**: 2026-08-22T19:50:00+00:00 (verified — fix already present on origin/master)
- **Assessment**: ./assessment.md
- **Status**: verified-fixed (no new `lib/src` change required)

## Summary

The reported JIT/FFI `InvalidType`/`FunctionType` crash for `zfa make` with a
missing/invalid JSON config is **not reproducible on current `origin/master`
(`c0b3758`)**. The crash was a downstream symptom of broken `lib` imports /
uncompilable sources after the `zuraffa`/`zuraffa_flutter` split; with `lib`
compiling cleanly, the CLI reaches its argument-validation branch and prints
friendly messages (json-not-found, usage, migration guidance).

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/commands/make_command.dart` + supporting lib sources | already fixed (no change made) | Split-era compile fixes already merged (see #258). |

## Diff Highlights

No new diff — the fix (clean `lib` compile after the package split) is already
merged. The `make` edge-case validation path now executes and emits friendly
output.

## Tests Added or Updated

- None required: `test/cli/cli_edge_cases_test.dart` already asserts the 4
  friendly-message edge cases.

## Local Verification

- `dart test test/cli/cli_edge_cases_test.dart` →
  `+4: All tests passed!` (exit 0) on `origin/master` `c0b3758`.

## Deviations from Assessment

None — assessment concluded the fix is already applied.

## Follow-ups

- Close GitHub issue #249.
