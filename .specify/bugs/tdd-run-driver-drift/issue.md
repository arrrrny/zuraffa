# Bug Issue: fix(tdd): run driver misclassifies #657 success as generation-error — U1 stays pending when test goes green

- **Slug**: tdd-run-driver-drift
- **Fetched**: 2026-09-01
- **Issue**: 693
- **URL**: https://github.com/arrrrny/zuraffa/issues/693
- **State**: open
- **Severity**: unknown
- **Author**: arrrny
- **Labels**: bug

## Body

## Summary

After fix #657 (generator surface for plain functions), `zfa tdd make <id>` for behaviors that have a stubbed func body returns `drift` (test already passes) when the implementation is enough. But `zfa tdd run` reports the same scenario as `generation-error` and marks the behavior as `pending` instead of `green`/`done`.

## Reproduction

1. Forklift spec 004, U1 (`render returns a non-empty string for a fully populated task`)
2. Run `zfa tdd run 004-cloud-agent-task-dispatch` from a clean state
3. A1-A5 deferred as `unexpressible` (expected)
4. U1:gen → ok, U1:verify-red → certified (expected)
5. U1:make → the #657 fix fires: stub rewritten to `String subject_u1() { return 'subject_u1'; }`
6. Test `dart test test/tdd/u1_test.dart` → passes
7. `zfa tdd make U1` direct call → `outcome=drift` (test already passes — success)
8. **But the run driver reports** `step failed — behavior=U1 step=make outcome=generation-error` and leaves U1 in `pending` state

## Expected

When `zfa tdd make` returns `drift` AND the test is green:
- The run driver should classify the step as `green` (success)
- U1 should transition from `pending` → `green` → `done` (or whatever the canonical state name is)
- The run should proceed to U2

## Actual

The run driver maps `drift` to `generation-error` and hard-stops the run.

## Root cause

`run_command.dart` has an outcome mapping table (from the bug #625 refactor). It needs an entry for `drift` (the new outcome introduced by #657) that classifies as `green` (success). Currently `drift` is unmapped and falls through to `generation-error`.

## Verification

- A `zfa tdd run` with the new binary should reach U1:make, see `drift`, classify as `green`, transition U1 to done, and proceed to U2.
- The misfire should be logged once with a clear note (e.g. "U1 was already green from a prior make") rather than aborting the whole run.

## Context

Reported on 2026-09-01 while running `zfa tdd run` on forklift spec 004. U1 is a plain-function behavior that hits the new #657 generator. The test passes (`All tests passed!`) but the run driver doesn't recognize the success path.

## Comments

None.
