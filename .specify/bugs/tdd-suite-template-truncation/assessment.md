# Bug Assessment: loadSuiteTemplate truncates multi-word unquoted commands to first word

- **Slug**: tdd-suite-template-truncation
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/726
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

After the merged fix for #681, `SingleTestRunner.loadSuiteTemplate()` (and likely `loadSingleTemplate()`) returns only the first word of a multi-word command. The unquoted-value pattern `[^\s#]+` stops at the first whitespace, so `suite: dart test` is read as `suite: dart`. This causes `zfa tdd make` to run `dart` (no args) for the suite baseline, which exits 0 — then `make` refuses with "the suite baseline did not produce a usable snapshot".

## Symptom

`zfa tdd make U1` → `suite baseline: dart` (truncated) → `baseline exit: 0, failed: 0` → "the suite baseline did not produce a usable snapshot". The real test suite never runs.

## Reproduction

1. `zfa tdd init` on a pure Dart package
2. Profile has `suite: dart test` (unquoted)
3. `zfa tdd gen U1` + `zfa tdd verify-red U1`
4. `zfa tdd make U1 --feature <feature>`
5. → `suite baseline: dart` → refuses with "no usable snapshot"

## Suspected Code Paths

- `lib/src/plugins/tdd/services/runner.dart` — `loadSuiteTemplate()` and `loadSingleTemplate()` regex for unquoted values

## Root Cause Hypothesis

The regex `r'''^\s*suite:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+))\s*$'''` uses `[^\s#]+` for unquoted values, which matches only a single word. For `suite: dart test`, group 3 captures only `dart`. Confidence: **high** — the issue author identified the exact regex and the exact fix.

## Proposed Remediation

Change the unquoted alternative from `[^\s#]+` to `\S+(?:\s+\S+)*` in both `loadSingleTemplate` and `loadSuiteTemplate` regexes:

```dart
r'''^\s*suite:\s*(?:"(.+?)"|'(.+?)'|(\S+(?:\s+\S+)*))\s*$'''
```

**Files likely to change**:
- `lib/src/plugins/tdd/services/runner.dart`

**Tests to add or update**:
- `loadSuiteTemplate` with unquoted `suite: dart test` → returns `dart test`
- `loadSingleTemplate` with unquoted `single: dart test -n "{name}"` → returns full command
- `zfa tdd make` on a pure-Dart package with unquoted multi-word suite → suite baseline runs the real suite

## Risks & Considerations

- This is a regression from the #681 fix. The fix must preserve the quoted-value behavior.
- The new pattern `\S+(?:\s+\S+)*` must not swallow trailing comments — verify the `\s*$` anchor still works.

## Open Questions

- None blocking — the issue author provided the exact fix.
