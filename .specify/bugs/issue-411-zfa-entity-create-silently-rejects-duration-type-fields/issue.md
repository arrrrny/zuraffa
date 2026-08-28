# Bug Issue: zfa entity create: silently rejects Duration type fields

- **Slug**: issue-411-zfa-entity-create-silently-rejects-duration-type-fields
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 411
- **URL**: https://github.com/arrrrny/zuraffa/issues/411
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

**Bug**: `zfa entity create` rejects `Duration` type fields — writes no files, no error message.

**Reproduction**:
1. `zfa entity create -n StopPolicy --field "wallClockTimeout:Duration"`
2. Entity not created, no output file, silent failure.

**Expected**: Either accept `Duration` (generate `Duration? wallClockTimeout;`) or show clear error: "Duration not supported, use int (milliseconds) instead".

**Files**: Entity creation validation in `lib/src/commands/entity_command.dart` or the Zorphy plugin.


## Comments

None.
