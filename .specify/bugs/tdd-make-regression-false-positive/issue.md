# Bug Issue: fix(tdd): make's regression check counts pre-existing red behaviors — false positive when A* behaviors are deferred

- **Slug**: tdd-make-regression-false-positive
- **Fetched**: 2026-09-01
- **Issue**: 731
- **URL**: https://github.com/arrrrny/zuraffa/issues/731
- **State**: open
- **Severity**: unknown
- **Author**: arrrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

`zfa tdd make` reports `outcome=regression` when the suite guard sees 1+ new failure, but it doesn't distinguish between NEW failures (caused by this make) and PRE-EXISTING failures (caused by prior deferred behaviors). When acceptance behaviors (A1-A5) are correctly deferred at phase-1 make, they leave the suite with 5 failing tests. Any subsequent unit behavior's make sees "1 new failure" (the pre-existing red count) and reports `regression` instead of `skipped`.

## Reproduction

```bash
# State: spec 004 with A1-A5 deferred (red), U1 green, U2 just generated
# Expected: U2:make returns outcome=skipped (test already passes)
# Actual:   U2:make returns outcome=regression
```

Direct call to `zfa tdd make U2` shows `outcome=skipped`, but when called from `zfa tdd run`, the run driver reports `outcome=regression`.

## Root cause

In `lib/src/plugins/tdd/commands/make_command.dart:420-446`:
```dart
if (diff.hasNewFailures) {
  print('zfa tdd make: regression detected — ${diff.newFailures.length} NEW failure(s)...');
  outcome: MakeOutcome.regression
}
```

The `diff.hasNewFailures` check counts failures in the full suite vs a pre-make baseline. When the baseline snapshot is taken AFTER A1-A5 are deferred (5 failing tests already), the guard's comparison logic thinks the current behavior caused a new failure.

## Expected

- Make should compare the count of failures in the CURRENT behavior's test file (or test name) against the baseline, not the full suite.
- If only the current test passes, report `outcome=skipped` (per #694) regardless of other behaviors being red.
- A regression should only be reported when a test that was previously passing is now failing because of this make.