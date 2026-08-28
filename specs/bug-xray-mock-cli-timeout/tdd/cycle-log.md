# TDD Cycle Log — issue #531

## RED (before fix)

Running `dart test test/commands/xray_mock_cli_test.dart` (single file, no
explicit `-j4`): every test in the group hit the 2-minute timeout.

```
00:02 +0 -1: zfa xray mock CLI integration <name> [E]
  TimeoutException after 0:02:00.000000: Test timed out after 2 minutes.
```

Measurement of the actual cost (outside the test):
- `dart bin/zfa.dart xray --help` (cold) → ~23s wall.
- `dart bin/zfa.dart xray mock` (cold) → ~24s wall.
- `ZfaConfig.load` only reads one `.zfa.json`; constructing the 27 plugins is
  microsecond-scale. So `PluginLoader.buildRegistry()` is NOT the bottleneck.

Root cause: the 2-min timeout is on the **group**, and the group spawns the CLI
**six** times (5× `xray mock` + 1× `xray deck`). 6 × ~24s ≈ 144s > 120s, so the
group cannot finish even unloaded. CPU contention makes each spawn worse.

## GREEN (after fix)

- `test/helpers/run_zfa_source.dart` precompiles `bin/zfa.dart` to an AOT exe
  once in `setUpAll` and runs it. Measured spawn time dropped from ~24s to
  ~0.02s (`xray mock` via the exe: `0.017574892s`). The whole group now runs in
  well under 2 minutes.
- `lib/src/cli/cli_runner.dart` additionally skips `buildRegistry()` for the
  plugin-free `xray` command (verified it has no plugin-registry dependency).
- The spawn is wrapped in a 5-minute kill guard.

`dart test test/commands/xray_mock_cli_test.dart` → all tests pass.

`dart analyze lib/src/cli test/helpers` → `No issues found!`
