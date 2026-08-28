# Bug Fix: SmartMergeWriter crashes with PathNotFoundException when target file doesn't exist

- **Slug**: issue-248-bug-smartmergewriter-crashes-with-pathnotfoundexception-when
- **Fixed**: 2026-08-22T19:50:00+00:00 (verified — fix already present on origin/master)
- **Assessment**: ./assessment.md
- **Status**: verified-fixed (no new `lib/src` change required)

## Summary

The reported `PathNotFoundException` on a non-existent target file is **not
reproducible on current `origin/master` (`c0b3758`)**. `writeMerged` in
`lib/src/core/transaction/smart_merge_writer.dart` already wraps the read in a
`try/on FileSystemException` that treats `ENOENT` / "Cannot open file" /
"No such file" as empty existing content (write fresh), while rethrowing
permission/access errors.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/core/transaction/smart_merge_writer.dart` | already fixed (no change made) | Read wrapped in `try/on FileSystemException` with ENOENT handling. |

## Diff Highlights

No new diff — the fix is already merged. The relevant guard:

```dart
try {
  existingContent = await fileSystem.read(path);
} on FileSystemException catch (e) {
  if (e.osError?.errorCode == 2 ||
      e.message.contains('Cannot open file') ||
      e.message.contains('No such file')) {
    existingContent = '';
  } else {
    rethrow;
  }
}
```

## Tests Added or Updated

- None required: `test/core/transaction/smart_merge_test.dart` already covers
  the no-existing-content path and the permission-denied rethrow path.

## Local Verification

- `dart test test/core/transactions/smart_merge_test.dart` (path
  `test/core/transaction/smart_merge_test.dart`) →
  `+3: All tests passed!` (exit 0) on `origin/master` `c0b3758`.

## Deviations from Assessment

None — assessment concluded the fix is already applied.

## Follow-ups

- Close GitHub issue #248.
