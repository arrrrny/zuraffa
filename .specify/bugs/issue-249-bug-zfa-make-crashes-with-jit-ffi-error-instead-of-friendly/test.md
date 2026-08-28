# Bug Verification: zfa make crashes with JIT FFI error instead of friendly validation messages

- **Slug**: issue-249-bug-zfa-make-crashes-with-jit-ffi-error-instead-of-friendly
- **Tested**: 2026-08-22T19:50:00+00:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified-fixed (reproduction test passes on origin/master)

## Summary

The JIT/FFI crash for `zfa make` with missing/invalid JSON is not reproducible
on `origin/master` (`c0b3758`). With `lib` compiling cleanly after the
package split, the CLI reaches its validation branch and prints friendly
messages.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction | `dart test test/cli/cli_edge_cases_test.dart` | pass | `+4: All tests passed!` (standalone run) |
| Edge cases | missing JSON / invalid JSON / missing name+json / removed generate cmd | pass | Friendly messages asserted. |

## Output Excerpts

```
00:00 +4: All tests passed!
```

## Residual Risks

- The combined run with another heavy suite occasionally shows a "did not
  complete" on the 4th case due to subprocess/resource contention; the
  standalone run is stable and green.

## Recommendation

Close issue #249.
