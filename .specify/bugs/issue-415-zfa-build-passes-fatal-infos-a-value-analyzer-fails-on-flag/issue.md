# Bug Issue: zfa build: passes --fatal-infos a value → analyzer fails on flag → false 'no errors'

- **Slug**: issue-415-zfa-build-passes-fatal-infos-a-value-analyzer-fails-on-flag
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 415
- **URL**: https://github.com/arrrrny/zuraffa/issues/415
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

**Bug**: `zfa build` runs `dart analyze --fatal-infos <value>` but `--fatal-infos` is a boolean flag (no value). `dart analyze` errors on the flag usage, zfa catches the error and falsely reports `✅ dart analyze: no errors`.

**Reproduction**:
1. `zfa build` on any project with analyzer errors
2. Output shows: `Flag option "--fatal-infos" should not be given a value.` then `✅ dart analyze: no errors`
3. Actual `dart analyze` shows errors

**Expected**: `zfa build` should run `dart analyze --fatal-infos` (boolean) or `dart analyze --fatal-infos --fatal-warnings` without a value.

**Files**: `lib/src/commands/build_command.dart` or wherever the analyze command is constructed.


## Comments

None.
