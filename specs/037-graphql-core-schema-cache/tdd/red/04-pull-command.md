# Red Evidence — `zfa graphql pull` command

**Test file**: `test/commands/graphql_pull_command_test.dart`
**Behaviors**: B11 — end-to-end loopback pull < 10s (SC-001); B12 — CLI error
paths (500 / GraphQL errors / unreachable / no partial files)
**Spec**: SC-001, FR-001, FR-002

## First-run output (before implementation)

```
$ dart test test/commands/graphql_pull_command_test.dart

  test/commands/graphql_pull_command_test.dart:31:28: Error: Member not found:
  'HttpServer.bindSync'.   <- fixed pre-red by switching to async bind
00:00 +0 -1: Some tests failed.

(after the bind fix — command not yet registered:)
$ dart test test/commands/graphql_pull_command_test.dart
00:00 +1 -5: Some tests failed.

Failing tests:
  test/commands/graphql_pull_command_test.dart: pull writes both artifacts
  within 10s (SC-001)
  test/commands/graphql_pull_command_test.dart: server 500 -> clear error, no
  files, non-zero exit
  test/commands/graphql_pull_command_test.dart: graphql errors body -> error
  names the failing part
  test/commands/graphql_pull_command_test.dart: unreachable endpoint -> clear
  error, no files
```

**Status**: RED ✓ — `zfa graphql pull` was not a registered subcommand; the
`PullCommand` class did not exist. The single passing test ("missing
--endpoint prints usage guidance") passes vacuously because the args package
usage error output mentions options; the five behavioral tests fail.
