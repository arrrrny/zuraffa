# Bug Assessment: zfa build: passes --fatal-infos a value → analyzer fails on flag → false 'no errors'

- **Slug**: issue-415-zfa-build-passes-fatal-infos-a-value-analyzer-fails-on-flag
- **Created**: 2026-08-22T19:42:20.566186+00:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/415
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

`zfa build` runs a post-build `dart analyze` guard. That guard was invoking
`dart analyze --fatal-infos=false lib`, which the Dart analyzer rejects at
flag-parse time:

```
Flag option "--fatal-infos" should not be given a value.
```

Because the analyzer aborts before producing any analysis output, `stdout` is
empty, `analyzeReportsError("")` is `false`, and the guard falsely reports
"✅ dart analyze: no errors" — masking genuinely broken generated code.

## Symptom

`zfa build` reports success ("no errors") even when generated code does not
compile, because the `dart analyze` invocation fails at flag-parse and yields
no output for the guard to inspect.

## Reproduction

1. Introduce a compile error into generated `lib/` code.
2. Run `zfa build` (with the analyze guard on).
3. Observe the build prints "✅ dart analyze: no errors" despite the broken code.
   (Root cause confirmed directly: `dart analyze --fatal-infos=false lib` exits 64
   with the "should not be given a value" message and empty stdout.)

## Suspected Code Paths

- `lib/src/commands/build_command.dart:367` — `verifyAnalyzeOrFail` builds the
  `Process.run('dart', ['analyze', '--fatal-infos=false', 'lib'])` argument list.
- `lib/src/commands/build_command.dart:402` — `analyzeReportsError` only inspects
  stdout for `error` severity lines; with empty stdout it always returns `false`.

## Root Cause Hypothesis

`--fatal-infos` is a boolean flag. Passing `--fatal-infos=false` (a value) is
rejected by the analyzer (`exit 64`), so the analyze step never runs and the
guard's error-detection sees empty output → false "no errors". Confidence: high
(reproduced directly via the CLI).

## Proposed Remediation

Drop the invalid `--fatal-infos=false` argument. By default `dart analyze` does
NOT treat info-level issues as fatal, which is exactly the desired behavior
(errors fail the build; warnings/info do not). The guard's
`analyzeReportsError` parser already keys off `error` severity lines, so error
detection is preserved.

**Files likely to change**:
- `lib/src/commands/build_command.dart` (remove the bad flag + update comment)
- `test/commands/build_command_unit_test.dart` (add regression test)

**Tests to add or update**:
- A test that runs `verifyAnalyzeOrFail()` against the current package and
  expects `true` (proving the analyzer invocation no longer fails at flag-parse).

## Risks & Considerations

- None significant. Info-level lints remain non-fatal, matching the documented
  guard contract ("Only ERRORS fail the build").
- The existing `analyzeReportsError` unit tests (#395) are unchanged.

## Open Questions

- None.
