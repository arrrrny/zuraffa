# Red Evidence — `zfa graphql diff` command (exit codes)

**Test file**: `test/commands/graphql_diff_command_test.dart`
**Behaviors**: B21 — exit 1 with breaking / exit 0 clean (FR-004); B22 —
unknown name lists cached schemas; no-previous-version suggests pull;
`--old`/`--new` overrides
**Spec**: FR-004, SC-004

## First-run output (before implementation)

```
$ dart test test/commands/graphql_diff_command_test.dart

  test/commands/graphql_diff_command_test.dart:7:8: Error: Error when reading
  'lib/src/graphql/cache/schema_cache.dart' ... (pull/write API missing)
00:00 +0 -1: Some tests failed.

Failing tests:
  test/commands/graphql_diff_command_test.dart: loading
```

(compile-red: depends on the 037 `SchemaCache.write/loadPrevious` API and the
not-yet-registered `diff` subcommand; all five tests fail at load)

**Status**: RED ✓
