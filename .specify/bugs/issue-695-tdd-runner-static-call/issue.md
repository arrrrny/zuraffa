# Bug Issue: fix(tdd): runner.dart calls static _firstMatchValue as instance method — compile error

- **Slug**: issue-695-tdd-runner-static-call
- **Fetched**: 2026-09-01
- **Issue**: 695
- **URL**: https://github.com/arrrrny/zuraffa/issues/695
- **State**: open
- **Severity**: unknown
- **Author**: arrrny
- **Labels**: bug

## Body

## Summary

`lib/src/plugins/tdd/services/runner.dart` calls `_firstMatchValue(...)` as an instance method, but the method is declared `static`. This causes a compile error:

```
runner.dart:95:22: Error: The method '_firstMatchValue' isn't defined for the type 'SingleTestRunner'.
    - 'SingleTestRunner' is from 'package:zuraffa/src/plugins/tdd/services/runner.dart' ('../zuraffa/lib/src/plugins/tdd/services/runner.dart').
   Try correcting the name to the name of an existing method, or defining a method named '_firstMatchValue'.
```

## Reproduction

```bash
# In any repo with a tdd test list:
zfa tdd run <feature>
# Run stops at the first A*:make step (where the runner resolves templates)
# with: behavior=A3 step=make outcome=failed
#            runner.dart:95:22: Error: The method '_firstMatchValue' isn't defined
```

## Root cause

In `lib/src/plugins/tdd/services/runner.dart`:
- Line 257: `static String? _firstMatchValue(String pattern, String input) { ... }`
- Lines 95, 120, 130, 173, 195, 203: called as instance method `final x = _firstMatchValue(...)`

Static methods cannot be called as instance methods in Dart without `ClassName.method` syntax. The six callers all omit the prefix.

## Proposed fix

Two options:
- **Option A (minimal):** Prefix the six callers with `SingleTestRunner.` (or just the class name) to use the static method.
- **Option B (preferred):** Remove the `static` keyword from line 257 — keep it an instance method, accessible without prefix. This is the conventional Dart style for helper methods that don't need static scoping.

```diff
- static String? _firstMatchValue(String pattern, String input) {
+ String? _firstMatchValue(String pattern, String input) {
```

## Verification

- `dart analyze lib/src/plugins/tdd/services/runner.dart` → zero errors
- `zfa tdd run <feature>` proceeds past A*:make for acceptance behaviors (subsequent unexpressible/deferred is expected, but no compile error)
- Existing tests pass

## Context

Discovered on 2026-09-01 running `zfa tdd run` on forklift spec 004 with the post-#657 binary. A1, A2 short-circuited to `unexpressible` (cached), A3 hit the compile error and the run stopped.

## Comments

None.
