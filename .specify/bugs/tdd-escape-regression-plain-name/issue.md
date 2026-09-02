# Bug Issue: fix(tdd): _escapeRegExp in runner.dart breaks --plain-name regex — escaped dots fail to match

- **Slug**: tdd-escape-regression-plain-name
- **Fetched**: 2026-09-02
- **Issue**: 859
- **URL**: https://github.com/arrrrny/zuraffa/issues/859
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

The `_escapeRegExp` function in `runner.dart:_tokenize` escapes regex metacharacters (`.` → `\.`) in test names before passing them to `dart test --plain-name`. But `dart test --plain-name` does NOT interpret backslash escapes — `DispatchResult\.success` does NOT match `DispatchResult.success`, so the test is never found and the runner reports exit 79 (no tests ran), classified as `runner-error`.

## Steps to Reproduce

```bash
# Any test name containing a dot triggers this:
dart test test/tdd/u20_test.dart --plain-name 'DispatchResult.success'
# → matches (exit 1, test runs)

dart test test/tdd/u20_test.dart --plain-name 'DispatchResult\.success'
# → "No tests ran." (exit 79)
```

The runner produces the second form because `_tokenize` calls `_escapeRegExp(name)` which escapes `.` to `\.`.

## Root cause

`lib/src/plugins/tdd/services/runner.dart:401`:
```dart
final escapedName = _escapeRegExp(name);
```

The `_escapeRegExp` method escapes regex metacharacters (`\^$.*+?()[]{}`), but `dart test --plain-name` treats the argument as a literal regex (no escape interpretation). The escaping is incorrect for this use case.

## Expected

Test names should be passed to `--plain-name` WITHOUT regex escaping. The names come from test-list.md which contains human-readable descriptions, not regex patterns. The `.` in `DispatchResult.success` should be passed literally as `.`.

## Actual

The `_escapeRegExp` escapes `.` to `\.``, making `dart test --plain-name` fail to match any test name containing dots. All behaviors whose names contain dots (U13-U20 in spec 004) hit `runner-error`.

## Verification

- U20: `dart test test/tdd/u20_test.dart --plain-name 'DispatchResult.success'` → matches (exit 1)
- All U* behaviors with dots in names go green instead of runner-error
- No regression for U* behaviors without dots (U1-U12)

## Context

Discovered on 2026-09-02 running `zfa tdd run` on forklift spec 004. U9-U18 all green (no dots in names). U19 green (backticks but no dots). U20 failed with runner-error because its name contains `DispatchResult.success` (dot).

The fix is simple: remove or comment out the `_escapeRegExp` call in `_tokenize`:
```dart
// Before:
final escapedName = _escapeRegExp(name);
// After:
final escapedName = name; // dart test --plain-name doesn't interpret escapes
```

Or if regex escaping is genuinely needed for some other use case, make it conditional (only escape for regex contexts, not for `--plain-name`).

## Comments

None.
