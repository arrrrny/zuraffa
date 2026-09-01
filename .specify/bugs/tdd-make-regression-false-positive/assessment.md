# Bug Assessment: zfa tdd make's regression check counts pre-existing red behaviors — false positive when A* behaviors are deferred

- **Slug**: tdd-make-regression-false-positive
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/731
- **Verdict**: valid
- **Severity**: high

## Report

`zfa tdd make` reports `outcome=regression` when the suite guard sees 1+ new failure, but it doesn't distinguish between NEW failures (caused by this make) and PRE-EXISTING failures (caused by prior deferred behaviors). Direct call says `skipped` (test passes), but run driver says `regression`.

## Symptom

Spec 004 with A1-A5 deferred (5 red), U1 green, U2 test passes → `U2:make` false-positived as `regression` due to pre-existing red A1-A5 tests in the suite baseline.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/make_command.dart:420-446` — `diff.hasNewFailures` check counts full-suite failures vs baseline.

## Root Cause Hypothesis

The suite-guard logic counts failures in the full suite vs a pre-make baseline. When the baseline snapshot is taken AFTER A1-A5 are deferred (5 failing tests already), the guard's comparison logic thinks the current behavior caused a new failure. It should compare only the current behavior's test file, not the full suite. Confidence: **high** — the reproduction is deterministic and the direct-call vs run-driver mismatch confirms it.

## Proposed Remediation

Make the regression check compare the count of failures in the CURRENT behavior's test file (or test name) against the baseline, not the full suite. If only the current test passes, report `outcome=skipped` (per #694) regardless of other behaviors being red.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/make_command.dart`

**Tests to add or update**:
- Spec with A1-A5 deferred (5 red), U1 green, U2 test passes → `U2:make` reports `outcome=skipped`, run continues to U2:refactor.
- A regression should only be reported when a test that was previously passing is now failing because of this make.

## Risks & Considerations

- This interacts with the #694 skip transition — ensure consistency between direct-call and run-driver paths.
- The suite-guard logic must still catch genuine regressions (a test that was passing before this make is now failing).

## Open Questions

- None blocking.