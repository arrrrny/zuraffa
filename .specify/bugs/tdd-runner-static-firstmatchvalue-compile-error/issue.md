# Bug Issue: fix(tdd): runner.dart calls static _firstMatchValue as instance method — compile error

- **Slug**: tdd-runner-static-firstmatchvalue-compile-error
- **Fetched**: 2026-09-01
- **Issue**: 695
- **URL**: https://github.com/arrrrny/zuraffa/issues/695
- **State**: open
- **Severity**: unknown
- **Author**: arrrrrny (Ahmet TOK)
- **Labels**: bug

## Body

`lib/src/plugins/tdd/services/runner.dart` calls `_firstMatchValue(...)` as an instance method, but the method is declared `static`. This causes a compile error.

## Reproduction

```bash
zfa tdd run <feature>
# Run stops at the first A*:make step with: runner.dart:95:22: Error: The method '_firstMatchValue' isn't defined
```

## Root cause

In `runner.dart`: line 257 declares `static String? _firstMatchValue(...)`, but lines 95, 120, 130, 173, 195, 203 call it as an instance method.

## Proposed fix

**Option B (preferred):** Remove the `static` keyword from line 257 — keep it an instance method.