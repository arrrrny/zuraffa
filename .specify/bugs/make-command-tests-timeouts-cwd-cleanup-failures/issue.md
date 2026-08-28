# Bug Issue: make_command tests: Timeouts + CWD cleanup failures

- **Slug**: make-command-tests-timeouts-cwd-cleanup-failures
- **Fetched**: 2026-08-27T14:26:39.439180+00:00
- **Issue**: 503
- **URL**: https://github.com/arrrrny/zuraffa/issues/503
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

# Bug Assessment: MakeCommand Integration Tests Timeout and CWD Issues

**Slug**: `007-zuraffa-v5-foundation-make-command-test-timeouts`  
**Feature**: `007-zuraffa-v5-foundation`  
**Severity**: Medium  
**Status**: Open

---

## Summary

Two integration tests in `test/commands/make_command_test.dart` timeout after 2 minutes and then fail with `PathNotFoundException` when the test workspace is cleaned up:
1. "#346 — with di --use-mock registers the mock datasource"
2. "#412 — full plugin bundle (repository usecase di mock provider service datasource) does not crash with bool→String? cast"

---

## Root Cause

The tests run `zfa make` as a subprocess with a temp working directory. After the subprocess completes (or times out), the test's `tearDown` tries to delete the temp workspace. However, the subprocess may still be running or the CWD becomes invalid, causing:
1. Test timeout (2 minutes) - generation taking too long
2. `PathNotFoundException: Getting current working directory failed, path = ''` - CWD invalidated

---

## Expected Behavior

Tests should complete within a reasonable time (< 30s) and clean up properly.

---

## Actual Behavior

Tests timeout after 2 minutes, then fail with CWD error during cleanup.

---

## Impact

- False negative test failures in CI
- Masks real regressions in the MakeCommand implementation
- Wastes CI time

---

## Test Cases

**File**: `test/commands/make_command_test.dart`
- Line ~418: "#346 — with di --use-mock registers the mock datasource"
- Line ~527: "#412 — full plugin bundle (repository usecase di mock provider service datasource) does not crash with bool→String? cast"

---

## Related to v5 Foundation

Partially - these tests exercise v5 foundation features (DI plugin, full plugin bundle) but the timeout/CWD issue is a test infrastructure problem.

---

## Recommendation

1. **Reduce test scope**: Use simpler entities or fewer plugins for faster generation
2. **Fix CWD handling**: Ensure subprocess doesn't inherit test's CWD that gets deleted
3. **Increase timeout**: Add `@Timeout(Duration(minutes: 3))` if generation is legitimately slow
4. **Use dry-run**: Use `--dry-run` flag to avoid actual file generation in these tests
5. **Separate unit vs integration**: Move fast unit tests out of the integration test group

---

## Stack Trace (from timeout)

```
PathNotFoundException: Getting current working directory failed, path = '' (OS Error: No such file or directory, errno = 2)
#0      _uriBaseClosure (dart:io-patch/directory_patch.dart:79:5)
#1      Uri.base (dart:core-patch/uri_patch.dart:21:41)
#2      Style._getPlatformStyle (package:path/src/style.dart:41:13)
#3      Style.platform (package:path/src/style.dart:33:33)
#4      new Context._internal (package:path/src/context.dart:49:23)
#5      createInternal (package:path/src/context.dart:14:37)
#6      context (package:path/path.dart:58:25)
#7      absolute (package:path/path.dart:136:5)
#8      ProjectRoot.find (package:zuraffa/src/core/project/project_root.dart:36:43)
#9      MakeCommand._findProjectRoot (package:zuraffa/src/commands/make_command.dart:82:24)
#10     new MakeCommand (package:zuraffa/src/commands/make_command.dart:66:25)
#11     CliRunner._ensureInitialized (package:zuraffa/src/cli/cli_runner.dart:81:24)
#12     CliRunner.run (package:zuraffa/src/cli/cli_runner.dart:96:5)
```

## Comments

None.
