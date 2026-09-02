# Bug Assessment: _escapeRegExp breaks --plain-name — escaped dots fail to match

- **Slug**: tdd-escape-regression-plain-name
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/859
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

The `_escapeRegExp` function in `runner.dart:_tokenize` escapes regex metacharacters (`.` → `\.`) in test names before passing them to `dart test --plain-name`. But `dart test --plain-name` does NOT interpret backslash escapes — `DispatchResult\.success` does NOT match `DispatchResult.success`, so the test is never found and the runner reports exit 79 (no tests ran), classified as `runner-error`. https://github.com/arrrrny/zuraffa/issues/859

## Symptom

All behaviors whose names contain dots (e.g. `DispatchResult.success`) hit `runner-error` because `_escapeRegExp` escapes `.` to `\.`, and `dart test --plain-name` doesn't interpret backslash escapes. U13-U20 in spec 004 all fail with exit 79.

## Reproduction

1. Any test name containing a dot triggers this
2. `dart test test/tdd/u20_test.dart --plain-name 'DispatchResult.success'` → matches (exit 1)
3. `dart test test/tdd/u20_test.dart --plain-name 'DispatchResult\.success'` → "No tests ran." (exit 79)
4. The runner produces the second form because `_tokenize` calls `_escapeRegExp(name)`

## Suspected Code Paths

- `lib/src/plugins/tdd/services/runner.dart:401` — `final escapedName = _escapeRegExp(name);` in `_tokenize`
- `lib/src/plugins/tdd/services/runner.dart` — `_escapeRegExp` method that escapes `\^$.*+?()[]{}`

## Root Cause Hypothesis

High confidence: `_escapeRegExp` was introduced (likely for issue #760 — regex escaping for `dart test -n`) but is now also applied when `--plain-name` is used. Since `--plain-name` treats its argument as a literal (no regex interpretation), escaping `.` to `\.`` breaks matching for any test name containing dots. The escaping is correct for `-n` (regex context) but wrong for `--plain-name` (literal context).

## Proposed Remediation

**Preferred**: Remove or conditionally skip the `_escapeRegExp` call when `--plain-name` is in use. The simplest fix: set `escapedName = name` when the template uses `--plain-name` instead of `-n`. Since `--plain-name` is a literal match, no escaping is needed.

**Alternatives** (optional):
- If both `-n` and `--plain-name` are supported, make `_escapeRegExp` conditional: escape only when the command template uses `-n` (regex context), skip when using `--plain-name` (literal context).

**Files likely to change**:
- `lib/src/plugins/tdd/services/runner.dart` — remove or conditionalize `_escapeRegExp` in `_tokenize`

**Tests to add or update**:
- A test asserting that a behavior name with dots (e.g. `DispatchResult.success`) is passed to `--plain-name` WITHOUT escaping
- Regression test: behavior names with dots should not produce runner-error

## Risks & Considerations

- Minimal risk: the fix removes escaping for `--plain-name` which doesn't interpret escapes anyway
- If `dart test -n` (regex mode) is still used elsewhere, `_escapeRegExp` must remain for that path — only skip it for `--plain-name`
- Verify no other callers of `_escapeRegExp` depend on it being always applied

## Open Questions

- [NEEDS CLARIFICATION: Is `_escapeRegExp` still needed for any code path that uses `dart test -n` (regex mode)? If so, the fix must be conditional rather than removing it outright.]
