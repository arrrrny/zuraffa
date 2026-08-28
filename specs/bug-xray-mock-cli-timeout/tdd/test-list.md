# TDD Test List — issue #531

## Outer acceptance behaviors (traced to the failing test)

- **A1** — `test/commands/xray_mock_cli_test.dart` › group `zfa xray mock CLI
  integration` (all 5 tests, including `next-step deck hint includes the
  required --source`) completes within the 2-minute *group* timeout.
  - Traced to: the failing group, which spawns the `zfa` CLI six times.
  - Acceptance criterion: `dart test test/commands/xray_mock_cli_test.dart`
    passes on Linux.

## Inner unit behaviors

- **U1** (`lib/src/cli/cli_runner.dart`) — `_ensureInitialized` does NOT run
  `PluginLoader.buildRegistry()` when the top-level command is plugin-free
  (`xray`); the core commands are still added and `PluginRegistry.instance`
  stays available for `make`/`manifest`/`apply`.
- **U2** (`test/helpers/run_zfa_source.dart`) — `initZfaSourceBin` builds a
  precompiled AOT executable for `bin/zfa.dart` (or falls back to `null`), and
  `runZfaSource` runs that executable instead of `dart bin/zfa.dart`, removing
  the per-spawn front-end/JIT compile.
- **U3** (`test/helpers/run_zfa_source.dart`) — a hung spawn is killed by a
  5-minute guard so it cannot occupy the test beyond that bound.
