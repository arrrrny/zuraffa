## Symptom

The test `zfa xray mock CLI integration next-step deck hint includes the required --source`
in `test/commands/xray_mock_cli_test.dart` launches the `zfa` CLI twice as a child `dart`
process (`xray mock` then `xray deck`) and expects both to finish within the 2-minute
per-test/group timeout. On Linux CI it does not finish in time and aborts with
`TimeoutException after 0:02:00.000000`, while the identical test passes on macOS.

Expected: both subprocess invocations complete and the deck-hint + generated-deck-file
assertions pass.

## Reproduction

1. From the zuraffa repo root, run `dart test test/commands/xray_mock_cli_test.dart` (or the
   full `dart test -j 4` suite) on a Linux x64 runner with Dart 3.13.1.
2. The group declares `timeout: const Timeout(Duration(minutes: 2))`
   (`test/commands/xray_mock_cli_test.dart:38`).
3. `setUpAll` resolves `bin/zfa.dart` via `initZfaSourceBin()`
   (`test/helpers/run_zfa_source.dart:27-31`).
4. The failing test creates a sandbox usecase file then calls `runZfaSource(...)` twice:
   - `zfa xray mock Order --root <tempDir>` (`test/commands/xray_mock_cli_test.dart:166-172`)
   - `zfa xray deck --entity Order --source <relpath> --root <tempDir>`
     (`test/commands/xray_mock_cli_test.dart:187-196`)
5. Each `runZfaSource` call is `Process.run('dart', [zfaSourceBin, ...args], ...)`
   (`test/helpers/run_zfa_source.dart:41-51`). `Process.run` has **no** child timeout, so a
   slow/zombied `dart` spawn blocks until the enclosing 2-minute group timeout fires.

Note: the commands themselves are deterministic and fast in isolation (pure synchronous
text/file edits). The hang is in the *spawning cost* / resource contention of the child
`dart` VM, not in the command logic. Reproduces on Linux CI under parallel load; not yet
reproduced locally.

## Suspected Code Paths

- `test/helpers/run_zfa_source.dart:41-51` — `runZfaSource` calls `Process.run('dart', ...)`
  with **no `timeout:` argument**. A slow or wedged child `dart` process will occupy the full
  2-minute group window before `Process.run` gives up. This is the immediate mechanism of the
  hard timeout (no fast-fail safety net).
- `test/commands/xray_mock_cli_test.dart:38` — group `Timeout(Duration(minutes: 2))`. The test
  spawns two full `dart` VM launches back-to-back (lines 166 and 187); it is ~2x more exposed
  to VM-startup cost than the single-spawn tests in the same file.
- `lib/src/cli/cli_runner.dart:49-92` — `_ensureInitialized()` runs
  `PluginLoader().buildRegistry()` on **every** `dart bin/zfa.dart` invocation, even for the
  `xray mock` / `xray deck` subcommands that do not consume the plugin registry. Heavy startup
  cost per child process amplifies CPU contention under `dart test -j 4`.
- `lib/src/commands/xray_mock_command.dart:139-153` — prints the "── Next steps ──" hint that
  the test asserts on. Synchronous; not a hang source, but the assertion target.
- `lib/src/commands/xray_deck_command.dart:170-185` — barrel update path; pure synchronous file
  writes via `XRayDeckBarrelWriter`, no `build_runner` / `dart analyze` / network.
- `lib/src/plugins/xray/xray_mock_scaffolder.dart` and
  `lib/src/plugins/xray/xray_deck_barrel_writer.dart` — text/regex + `File` I/O only; bounded
  work. Confirmed not the hang source.
- Confirmed NOT triggered: `lib/src/commands/build_command.dart` (build_runner/analyze) is not
  on this command path.

## Root Cause Hypothesis

Two contributing factors, Linux-specific:

1. **No child-process timeout in the test harness.** `runZfaSource` uses `Process.run` without
   a `timeout`. If a spawned `dart bin/zfa.dart` is slow to start or wedges (stalled auto-
   `dart pub get`, a kernel cache miss forcing a full JIT compile of the analyzer-backed CLI,
   or CPU starvation), the `Future` only resolves when the parent 2-minute group timeout kills
   the test — producing the observed `TimeoutException`.
2. **Per-invocation CLI startup cost under parallel load.** Each subprocess re-runs
   `CliRunner._ensureInitialized()` → `PluginLoader.buildRegistry()`, scanning/loading the
   plugin set even though `xray mock`/`deck` never use it. With `dart test -j 4`, several CLI
   test files (`make_command_test.dart`, `app_shell_command_test.dart`,
   `initialize_dart_inplace_test.dart`, `issue_320_..._e2e_test.dart`, plus this file) spawn
   `dart bin/zfa.dart` concurrently. On a CPU-constrained Linux runner the JIT startup of a
   heavy package compounded across parallel processes pushes at least one invocation past 2
   minutes. The macOS run passes because its runner has more headroom / faster `dart` startup.

The platform split (fails Linux only, passes macOS) is the signature of resource contention +
missing fast-fail rather than a logic bug. **Confidence: medium** (strong circumstantial
evidence; not yet reproduced by running the suite locally).

## Severity

medium — CI-reliability / test-hang defect on Linux. No user-facing correctness impact, but it
blocks the Linux `dart test` suite (hard timeout) and wastes CI minutes.

## Proposed Remediation

1. Add a bounded child timeout to the test harness so a slow/hung `dart` spawn fails *fast* and
   surfaces the real cause: give `Process.run` a `timeout:` (e.g. `Duration(minutes: 1)`) in
   `test/helpers/run_zfa_source.dart:46`, and on timeout throw a diagnostic error naming the
   exact `zfa` args.
2. Reduce per-invocation CLI startup cost: make `CliRunner._ensureInitialized()` lazily build
   the plugin registry only when a command actually needs it (or skip `PluginLoader.buildRegistry()`
   for non-plugin subcommands such as `xray mock`/`deck`).

Alternatives: raise the per-test group timeout (masks the problem, not recommended as the only
fix); or use the in-process `CliRunner.runCapturing` instead of `Process.run` (larger refactor
of the deliberate hermetic-subprocess pattern from issue #506).

## Open Questions

- Was the Linux runner CPU-constrained, and how many concurrent `dart` subprocess CLI tests ran
  during the failing run?
- Was `dart pub get` already satisfied in `.dart_tool` on the failing run, or could an auto-
  `pub get` in the child have stalled?
- Does the same test also flake on macOS under heavier parallelism, or is the asymmetry purely
  Linux resource headroom?

Assessment: .specify/bugs/xray-mock-cli-deck-hint-timeout/assessment.md
