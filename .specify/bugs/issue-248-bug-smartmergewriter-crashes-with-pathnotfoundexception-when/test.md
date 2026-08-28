# Bug Verification: SmartMergeWriter crashes with PathNotFoundException when target file doesn't exist

- **Slug**: issue-248-bug-smartmergewriter-crashes-with-pathnotfoundexception-when
- **Tested**: 2026-08-22T19:50:00+00:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified-fixed (reproduction test passes on origin/master)

## Summary

The `PathNotFoundException` on a non-existent target file is not reproducible
on `origin/master` (`c0b3758`). The read is guarded so missing files are
treated as empty content (write fresh) while permission errors propagate.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction | `dart test test/core/transaction/smart_merge_test.dart` | pass | `+3: All tests passed!` |
| No-existing-content | `writeMerged` on a path that does not exist | pass | Writes new content directly. |
| Permission rethrow | read-only existing file | pass | `FileSystemException` propagates, file untouched. |

## Output Excerpts

```
00:00 +3: All tests passed!
```

## Residual Risks

- None. The fix is already merged and covered by an existing regression test.

## Recommendation

Close issue #248.
