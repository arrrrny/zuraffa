# Bug Issue: [zfa tdd verify-red/make] dart test -n <name> treats parens as regex group — blocks behaviors whose description has (sticky) or (FR-XXX)

- **Slug**: tdd-parens-regex
- **Fetched**: 2026-09-02
- **Issue**: 760
- **URL**: https://github.com/arrrrny/zuraffa/issues/760
- **State**: open
- **Severity**: medium
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

`zfa tdd verify-red` and `zfa tdd make` pass the test name directly to `dart test -n "<name>"` without escaping regex metacharacters. When the behavior description contains parentheses (e.g. `(sticky)`, `(idempotent)`, `(FR-XXX)`), `dart test -n` treats them as a regex group, which causes:

- Either: no tests match ("No tests match regular expression ..." with exit code 79)
- Or: matches an unintended subset of tests

This blocks any behavior whose description includes regex metacharacters. The previous tdd cycle log (spec 044/046) noted this exact problem: `the single-test command matched nothing when given the full name with (FR-003) because package:test parsed the parentheses as a regex group`.

## Steps to Reproduce

1. `zfa tdd init` on a pure Dart package
2. `zfa tdd run <feature>` — succeeds for behaviors without parens (U1, U2)
3. Stops at U3: description ends with `(sticky)`
4. `dart test -n "U3 (FR-005, FR-006) \`request\` on an \`undetermined\` scope resolves the prepared prompt outcome and records it (sticky)"` → "No tests ran." exit 79
5. `verify-red` classifies as `runner-error`

## Expected Behavior

`zfa tdd verify-red` (and `zfa tdd make` for the single-test re-run) should escape regex metacharacters when running `dart test -n "<name>"`. The test name should be matched as a literal string.

## Root Cause

**File**: `lib/src/plugins/tdd/services/runner.dart` (and possibly the SingleTestRunner contract).

`SingleTestRunner.runSingle()` builds a `dart test -n <name>` command from the `single` template by substituting `{name}` with the runnable test name. The substitution is a plain `.replaceAll('{name}', name)` — no regex escaping. `dart test -n` accepts a regular expression (not a literal string), so any parens, dots, brackets, etc. in the name change the matching behavior.

## Suggested Fix

In `SingleTestRunner._tokenize` (or `_substitute`), after substituting `{name}` with the test name, escape regex metacharacters:

```dart
String _escapeRegExp(String s) {
  final special = RegExp(r'[\.\\^$*+?()\[\]{}|]');
  return s.replaceAllMapped(special, (m) => '\\${m.group(0)}');
}
```

Then in `_substitute`:
```dart
String _substitute(String template, String file, String name) =>
    template
        .replaceAll('{file}', file)
        .replaceAll('{name}', _escapeRegExp(name));
```

And in `_tokenize`, apply the same escape before returning each token.

## Alternative

`package:test` 1.25+ has a `--plain-name` flag that does literal string matching. Update the `single:` template default from `dart test -n "{name}"` to `dart test --plain-name "{name}"` for test runners that support it.

## Affected Versions

zfa v6.1.0+; affects any behavior whose description contains `(...)` or other regex metacharacters.

## Severity

medium — blocks `zfa tdd run` on a significant fraction of behaviors whose descriptions naturally include parenthetical notes (idempotent, sticky, FR-XXX, etc.)

## Comments

None.
