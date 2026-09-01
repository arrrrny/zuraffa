# Bug Issue: fix(tdd): refactor preflight is full dart test — fails when U3+ are still red

- **Slug**: tdd-refactor-preflight-full-suite
- **Fetched**: 2026-09-02
- **Issue**: 734
- **URL**: https://github.com/arrrrny/zuraffa/issues/734
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

## Summary

`zfa tdd refactor` runs a preflight `dart test` (full suite) and refuses to proceed if any test is red. When earlier-phase 1 has pending U* behaviors (U3-U44), the suite has 3+ red tests, and the preflight fails for every behavior. This blocks phase 2b refactor for ALL green behaviors, not just the ones whose own test passes.

## Reproduction

```bash
# State: A1-A5 all green (composed), U1-U2 green, U3-U44 pending (not generated)
# Run zfa tdd run — phase 2b refactor pass
# Output:
# [run] A5 refactor -> not-green
# zfa tdd refactor: preflight suite
#    command: dart test
#    preflight exit: 1
# zfa tdd run: step failed — behavior=A5 step=refactor outcome=not-green
```

The "not-green" verdict comes from the full `dart test` having any failure — even failures in behaviors they run hasn't reached yet (U3-U44).

## Root cause

In `lib/src/plugins/tdd/commands/refactor_command.dart` (presumed), the preflight runs `dart test` for the whole repo. Any pre-existing red behavior (U3-U44 that haven't been processed) causes the preflight to fail.

The phase 2b refactor contract (per the comment in run_command.dart:354-360) says: "every behavior still short of DONE now sits GREEN — the units whose refactor deferred in phase 1 plus the acceptance behaviors phase 2a just flipped — and every make in the feature is certified green, so the suite is fully green. Run refactor per behavior, in list order."

But that comment assumes the run gets to U3-U44 in phase 1 first. If the run stops at U2 (e.g., due to #731 false-positive), U3-U44 are still pending and their generated stubs throw UnimplementedError — which causes the suite to fail.

## Expected

The refactor preflight should be per-behavior, not full-suite. If `dart test test/tdd/<behavior>_test.dart` passes for the current behavior, refactor should proceed (the per-behavior absolute-green contract per spec 048 FR-001).

## Actual

Refactor preflight runs full `dart test` and fails if ANY test fails, even unrelated behaviors.

## Verification

- A run that processes A1-A5 + U1-U2 then stops (any reason) should still be able to refactor those 7 behaviors
- Refactor for A5 should pass if `dart test test/tdd/a5_test.dart` exits 0, even if `dart test` (full) fails due to U3+

## Context

Discovered on 2026-09-01 running `zfa tdd run` on forklift spec 004. A1-A5 reached green via compose, then A5:refactor hit `not-green` because the full suite has U3+ stubs throwing UnimplementedError.

Following STOP-ON-ROADBLOCK from zuraffa/AGENTS.md.

## Comments

None.