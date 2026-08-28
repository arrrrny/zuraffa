# Bug Verification: ZuraffaDIContainer.registerSingleton(override: true) crashes with null-check on get

- **Slug**: issue-246-bug-zuraffadicontainer-registersingleton-override-true-crash
- **Tested**: 2026-08-22T19:50:00+00:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified-fixed (reproduction test passes on origin/master)

## Summary

The null-check crash after `registerSingleton(override: true)` is not
reproducible on `origin/master` (`c0b3758`). The override path already
eagerly registers the concrete instance, so `get<T>()` resolves correctly.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction | `dart test test/core/module/di_container_override_test.dart` | pass | `+13: All tests passed!` |
| Override case | `registerSingleton<double>(() => 1.0)` then `registerSingleton<double>(() => 2.0, override: true)` → `expect(di.get<double>(), 2.0)` | pass | Exact issue scenario. |

## Output Excerpts

```
00:00 +13: All tests passed!
```

## Residual Risks

- None. The fix is already merged and covered by an existing regression test.

## Recommendation

Close issue #246 — verified fixed on master.
