# Bug Issue: fix(tdd): tdd func scaffolder return type stays int even when test expects String

- **Slug**: tdd-func-return-type-inference
- **Fetched**: 2026-09-03
- **Issue**: 920
- **URL**: https://github.com/arrrrny/zuraffa/issues/920
- **State**: open
- **Severity**: medium
- **Author**: arrrrny
- **Labels**: bug

## Body

When the entity-bearing plan (`zfa tdd wire U<n> --entity Task`) fires, the generated subject has return type `int` and returns `0` even when the behavior's paired test imports String, DispatchResult, or any non-int type. The stub return type comes from the `zfa tdd func` scaffolder's default (`int`) and isn't reconciled with the test's expected return shape.

## Comments

None.
