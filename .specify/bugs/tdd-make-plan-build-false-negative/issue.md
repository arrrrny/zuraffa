# Bug Issue: fix(tdd): make plan includes func scaffold that races with pre-existing red tests — generation-error instead of skipped

- **Slug**: tdd-make-plan-build-false-negative
- **Fetched**: 2026-09-02
- **Issue**: 737
- **URL**: https://github.com/arrrrny/zuraffa/issues/737
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

## Summary

`zfa tdd make` plans a 2-step generation for a unit behavior: `[zfa tdd func <id>, build]`. When the suite has pre-existing red tests (e.g., other U* behaviors still red), the suite-guard's "1 failed" reading causes make to fail with `generation-error` even though the func scaffold succeeded. Direct calls to `zfa tdd func` and the subsequent `zfa tdd make` both succeed; only the run driver's invocation of the plan fails.

## Reproduction

```bash
# State: U1-U2 green, U3 stub fresh (int -> throw UnimplementedError)
# U4 stub also fresh
# Run: zfa tdd run
# Output:
# [run] U3 gen -> ok
# [run] U3 verify-red -> certified
# [run] U3 make -> generation-error
# zfa tdd make: generation step failed at index 0 (scaffold the render function for behavior U3 from its description):
#    command: ... zfa tdd func U3
#    exit: 1
```

But the SAME `zfa tdd func U3` runs successfully from the command line.

## Root cause

The make plan runs `[func U3, build]`. The func scaffolder itself succeeds (`outcome=scaffolded`). The next step is `build`, which likely includes `dart test` as part of the suite guard. The full `dart test` exits 1 because U4+ have unimplemented stubs, and the suite-guard logic confuses that with the current make's regression — even though the current behavior's test passes.

## Expected

- A unit behavior's make should be checked per-behavior (e.g., `dart test test/tdd/u3_test.dart`), not full-suite
- If the current behavior's test passes after func scaffold, return `outcome=skipped` (per #694) and continue

## Actual

- Make plan reports `generation-error` due to a pre-existing red test in the suite
- Run driver stops on the false-negative

## Verification

- Run `zfa tdd run` past U2 (which is green) — U3:make should be `outcome=skipped`, not `generation-error`
- The run should continue through all U* behaviors

## Context

Discovered 2026-09-01 running zfa tdd run on forklift spec 004. The full run was progressing: A1-A5 done, U1-U2 done, now U3 hitting generation-error from a pre-existing red test in the full suite.

Same root cause as #731 but in a different code path (the make plan's build step vs the suite guard's regression check). This is a separate bug filing because the fix location is different: the plan-step runner vs the direct make runner.

Following STOP-ON-ROADBLOCK from zuraffa/AGENTS.md.

## Comments

None.