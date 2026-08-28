# Bug: `zfa xray mock`/`deck` integration test times out (issue #531)

**Issue:** #531 — `test/commands/xray_mock_cli_test.dart` "next-step deck hint
includes the required --source" (and every other test in the group) fails with
`TimeoutException after 0:02:00.000000: Test timed out after 2 minutes.` on
Linux.

**Symptom:** The test group (`timeout: 2 min`) launches the `zfa` CLI as a
subprocess **six times** in total (`xray mock` ×5 + `xray deck` ×1). Each
spawn of `dart bin/zfa.dart` cold-compiles the front-end + JIT of the entire
zuraffa package before running a single command (~20–25s on an unloaded
machine). 6 × ~24s ≈ 144s already exceeds the 2-minute *group* budget, even
with no CPU contention.

**Root cause (verified by measurement):** the bottleneck is the per-spawn
`dart` compile of the whole package, not `PluginLoader.buildRegistry()`
(building the 27-plugin registry is microsecond-scale — `ZfaConfig.load` only
reads one `.zfa.json`). The triage hypothesis (heavy `buildRegistry` per
launch) is incorrect for this codebase; the decisive cost is the repeated
CLI compile.

**Fix:**
1. `test/helpers/run_zfa_source.dart` precompiles `bin/zfa.dart` to an AOT
   executable once (in `setUpAll`) and runs that instead of `dart bin/zfa.dart`.
   Each spawn then takes milliseconds, so the group completes far inside the
   2-minute budget. Falls back to `dart` source if `dart compile exe` is
   unavailable, and is reused across test files when the source is unchanged.
2. `lib/src/cli/cli_runner.dart` skips the redundant `PluginLoader.buildRegistry()`
   boot for the plugin-free `xray` command (the core commands are still
   registered; `PluginRegistry.instance` remains available for `make`/`manifest`/
   `apply`). This removes the only non-trivial per-launch work on the `xray`
   path and is a genuine improvement for real `zfa xray` invocations.
3. `run_zfaSource` wraps every spawn in a 5-minute guard that kills a hung
   child (this SDK's `Process.run` lacks a `timeout`, so it is implemented with
   `Process.start` + `Process.kill`) so a true hang fails fast.

None of these touch the 2-minute test timeout, the test body, or the
`--source` assertion.
