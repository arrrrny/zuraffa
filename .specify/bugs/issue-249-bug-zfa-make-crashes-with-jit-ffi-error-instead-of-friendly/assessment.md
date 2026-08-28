# Bug Assessment: bug: zfa make crashes with JIT FFI error instead of friendly validation messages

- **Slug**: issue-249-bug-zfa-make-crashes-with-jit-ffi-error-instead-of-friendly
- **Created**: 2026-08-22T19:42:20.566186+00:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/249
- **Verdict**: already fixed on master (verified — reproduction test passes)
- **Severity**: test/v6/zfa_cli (per labels), not reproducible on current origin/master

## Report (verbatim or summarized)

`zfa make` crashed with a JIT/FFI `InvalidType`/`FunctionType` compile error
instead of printing friendly validation messages when the JSON config was
missing/invalid. Same FFI crash also appeared in the polymorphic mock codegen
test.

## Symptom

```
crash when compiling:
type 'invalidtype' is not a subtype of type 'functiontype' in type cast
#0      _FfiUseSiteTransformer._verifyAndReplaceNativeCallable ...
```

## Reproduction

`flutter test test/cli/cli_edge_cases_test.dart` — the 4 `make`/`generate`
edge cases.

## Suspected Code Paths

- `bin/zuraffa.dart` → `make` command path (CLI argument validation before any
  codegen).
- The crash was a downstream symptom of broken imports / uncompilable `lib`
  sources that surfaced during JIT compilation of the CLI, not a logic bug in
  the validation itself.

## Root Cause Hypothesis

The CLI crashed during JIT compile because `lib` had compile errors (post
`zuraffa`/`zuraffa_flutter` split). The fix resolved the broken imports /
missing builder registrations so the CLI compiles and reaches argument
validation, which then prints friendly messages ("json file not found", usage,
migration guidance).

## Proposed Remediation

Already applied on master: the codebase compiles cleanly (no broken imports),
so `zfa make` reaches its validation branch and the edge-case tests pass.

## Files likely to change

- `lib/src/commands/make_command.dart` and supporting lib sources (split-era
  compile fixes already merged via #258).

## Tests to add

- `test/cli/cli_edge_cases_test.dart` already asserts the 4 friendly-message
  cases; it passes on `origin/master` (`c0b3758`): `+4: All tests passed!`.

## Risks & Considerations

- None for the fix; it is present and verified.
- GitHub issue #249 is still OPEN although the fix is merged.

## Open Questions

- None. Not reproducible on current master.
