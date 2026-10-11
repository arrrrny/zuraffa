# TDD Test List — Spec 1358 mcp replay subcommand

Red pre-fix (command unregistered): B1–B6 red (`Could not find a
subcommand named "replay"` → exit 2 instead of the asserted verdicts);
B7 depends on the help body — recorded as observed.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | Two-call echo scenario replays GREEN: exit 0, `mcp-replay: session=signin calls=2 ok=2 failed=0`, receipt written | FR-1 / AS-1 | test/plugins/mcp/mcp_replay_command_test.dart |
| B2 | Unregistered tool → exit 1, `missing-tool`, `failed=1` | FR-2 / AS-2 | test/plugins/mcp/mcp_replay_command_test.dart |
| B3 | Unsatisfied expect_contains → exit 1, `mismatch` | FR-2 / AS-3 | test/plugins/mcp/mcp_replay_command_test.dart |
| B4 | Unscaffolded project → exit 1 with the `zfa mcp scaffold` hint, no spawn | FR-3 / AS-4 | test/plugins/mcp/mcp_replay_command_test.dart |
| B5 | Missing scenario file → exit 2 usage | FR-3 / AS-5 | test/plugins/mcp/mcp_replay_command_test.dart |
| B6 | Malformed scenario → exit 1 naming the file | FR-3 / AS-6 | test/plugins/mcp/mcp_replay_command_test.dart |
| B7 | `zfa mcp --help` lists replay | FR-4 / AS-6 | test/plugins/mcp/mcp_replay_command_test.dart |

## Red protocol

```
dart test test/plugins/mcp/mcp_replay_command_test.dart
```
