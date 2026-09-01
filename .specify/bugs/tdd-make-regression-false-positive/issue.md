# Issue #731 — fix(tdd): make's regression check counts pre-existing red behaviors — false positive when A* behaviors are deferred

Source: https://github.com/arrrrny/zuraffa/issues/731 (state: open, severity high)

## Summary

`zfa tdd make` reports `outcome=regression` when the suite guard sees 1+ new failure, but it doesn't distinguish between NEW failures (caused by this make) and PRE-EXISTING failures (caused by prior deferred behaviors). When acceptance behaviors (A1-A5) are correctly deferred at phase-1 make, they leave the suite with failing tests. Any subsequent unit behavior's make sees a "new failure" (the pre-existing red count) and reports `regression` instead of `skipped` (which it should report when its own test passes).

## Reproduction

```bash
# State: spec 004 with A1-A5 deferred (red), U1 green, U2 just generated
# Expected: U2:make returns outcome=skipped (test already passes)
# Actual:   U2:make returns outcome=regression
```

Direct call to `zfa tdd make U2` shows:

```
zfa tdd make: behavior U2
   feature: 004-cloud-agent-task-dispatch
   test: /Users/ahmettok/Developer/forklift/test/tdd/u2_test.dart
   target test already passes — skipping generation (issue #694 skip transition); re-certifying with the suite guard
   suite baseline: dart test
   baseline exit: 1, failed: 1
   green evidence appended to specs/004-cloud-agent-task-dispatch/tdd/cycle-log.md
make: behavior=U2 outcome=skipped feature=004-cloud-agent-task-dispatch
```

But when called from `zfa tdd run`, the run driver reports:

```
[run] U2 make -> regression
zfa tdd run: step failed — behavior=U2 step=make outcome=regression
```

The mismatch: direct call says `skipped` (test passes), run driver says `regression`. Root cause is the suite-guard logic counting pre-existing red behaviors (A1-A5) as "new failures."

## Root cause (as filed)

In `lib/src/plugins/tdd/commands/make_command.dart:420-446`:

```dart
if (diff.hasNewFailures) {
  print('zfa tdd make: regression detected — ${diff.newFailures.length} NEW failure(s)...');
  outcome: MakeOutcome.regression
}
```

The `diff.hasNewFailures` check counts failures in the full suite vs a pre-make baseline. When the baseline snapshot is taken AFTER A1-A5 are deferred (failing tests already present), the guard's comparison logic apparently thinks the current behavior caused a new failure.

## Expected

- Make should compare the count of failures in the CURRENT behavior's test file (or test name) against the baseline, not the full suite.
- If only the current test passes, report `outcome=skipped` (per #694) regardless of other behaviors being red.
- A regression should only be reported when a test that was previously passing is now failing because of this make.

## Verification

- Spec 004 with A1-A5 deferred (red), U1 green, U2 test passes
- `zfa tdd make U2` from `zfa tdd run` should report `outcome=skipped` and continue to U2:refactor
- The full run should proceed through all U* behaviors, not stop at U2:make

## Context

Discovered on 2026-09-01 running `zfa tdd run` on forklift spec 004 with the post-#720 binary. U1 went green correctly, U2:make false-positived as `regression` due to pre-existing red A1-A5 tests in the suite baseline.

Following STOP-ON-ROADBLOCK rule from zuraffa/AGENTS.md: filing and waiting for the merge before resuming.
