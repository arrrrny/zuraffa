# Bug Assessment: bug: SmartMergeWriter crashes with PathNotFoundException when target file doesn't exist

- **Slug**: issue-248-bug-smartmergewriter-crashes-with-pathnotfoundexception-when
- **Created**: 2026-08-22T19:42:20.566186+00:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/248
- **Verdict**: already fixed on master (verified — reproduction test passes)
- **Severity**: test (per labels), not reproducible on current origin/master

## Report (verbatim or summarized)

`SmartMergeWriter.writeMerged` threw `PathNotFoundException` when the target
file did not yet exist (read attempted before an existence check).

## Symptom

`PathNotFoundException: Cannot open file ... (OS Error: No such file or directory, errno = 2)`
from `DefaultFileSystem.read` inside `writeMerged`.

## Reproduction

`flutter test test/smart_merge_test.dart` — the
`SmartMergeWriter creates file when no existing content` case.

## Suspected Code Paths

- `lib/src/core/transaction/smart_merge_writer.dart:22` — read path.
- `lib/src/core/context/file_system.dart` — `DefaultFileSystem.read`.

## Root Cause Hypothesis

`writeMerged` called `fileSystem.read(path)` before verifying the file
exists; for a brand-new file the read threw instead of treating it as
"nothing to merge — write fresh".

## Proposed Remediation

Already applied on master: the read is wrapped in a `try/on FileSystemException`
that treats `ENOENT` / "Cannot open file" / "No such file" as empty existing
content (write fresh). Non-existence errors (permission, access) are rethrown.

## Files likely to change

- `lib/src/core/transaction/smart_merge_writer.dart` (already fixed)

## Tests to add

- `test/core/transaction/smart_merge_test.dart` already covers the
  no-existing-content path plus the permission-denied rethrow path; it passes
  on `origin/master` (`c0b3758`): `+3: All tests passed!`.

## Risks & Considerations

- None for the fix; it is present and verified.
- GitHub issue #248 is still OPEN although the fix is merged.

## Open Questions

- None. Not reproducible on current master.
