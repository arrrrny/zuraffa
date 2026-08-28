# Bug Assessment: `zfa xray mock`→`deck` CLI integration test hard-times-out on Linux

- **Slug**: xray-mock-cli-deck-hint-timeout
- **Created**: 2026-08-28
- **Source**: pasted text (automated triage, no human in the loop)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

Failing test (Linux): `test/commands/xray_mock_cli_test.dart`
Test name: `"zfa xray mock CLI integration next-step deck hint includes the required --source"`
Failure: `TimeoutException after 0:02:00.000000` — Test timed out after 2 minutes.

The test does not complete within the 2-minute per-test timeout on Linux. Classified by the
reporter as a "test that does not complete run" (platform / performance / hang) issue. The
suspected wait target is a spawned `dart` process (the CLI under test is run as a subprocess).

Environment: Linux x64, Dart SDK 3.13.1, default `dart test -j 4` suite.
Reference: macOS suite = 1640 pass / 1 skip / 9 fail; this Linux run = 1681 pass / 1 skip /
8 fail (this one is a hard timeout on Linux).

## Symptom

The test `zfa xray mock CLI integration next-step deck hint includes the required --source`
launches the `zfa` CLI twice as a child `dart` process (`xray mock` then `xray deck`) and
expects both to finish within the 2-minute per-test/group timeout. On Linux CI it does not
finish in time and aborts with `TimeoutException after 0:02:00.000000`, while the identical
test passes on macOS. Expected: both subprocess invocations complete and the deck hint +
generated deck file assertions pass.

## Reproduction

1. From the zuraffa repo root, run `dart test test/commands/xray_mock_cli_test.dart` (or the
   full `dart test -j 4` suite) on a Linux x64 runner with Dart 3.13.1.
2. The group declares `timeout: const Timeout(Duration(minutes: 2))` (see
   `test/commands/xray_mock_cli_test.dart:38`).
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
text/file edits — see Suspected Code Paths). The hang is in the *spawning cost* / resource
contention of the child `dart` VM, not in the command logic. Reproduces on Linux CI under
parallel load; not yet reproduced locally. [NEEDS CLARIFICATION: whether the Linux runner is
CPU-constrained and how many concurrent `dart` subprocess CLI tests run there.]

## Suspected Code Paths

- `test/helpers/run_zfa_source.dart:41-51` — `runZfaSource` calls `Process.run('dart', ...)`
  with **no `timeout:` argument**. A slow or wedged child `dart` process will occupy the full
  2-minute group window before `Process.run` gives up. This is the immediate mechanism of the
  hard timeout (no fast-fail safety net).
- `test/commands/xray_mock_cli_test.dart:38` — group `Timeout(Duration(minutes: 2))`. The
  test spawns two full `dart` VM launches back-to-back (lines 166 and 187); it is ~2x more
  exposed to VM-startup cost than the single-spawn tests in the same file.
- `lib/src/cli/cli_runner.dart:49-92` — `_ensureInitialized()` runs
  `PluginLoader().buildRegistry()` on **every** `dart bin/zfa.dart` invocation, even for the
  `xray mock` / `xray deck` subcommands that do not consume the plugin registry. Heavy startup
  cost per child process amplifies CPU contention under `dart test -j 4`.
- `lib/src/commands/xray_mock_command.dart:139-153` — prints the "── Next steps ──" hint that
  the test asserts on (`zfa xray deck --entity Order --source <relpath>`). Synchronous; not a
  hang source, but the assertion target.
- `lib/src/commands/xray_deck_command.dart:170-185` — barrel update path; pure synchronous
  file writes via `XRayDeckBarrelWriter`, no `build_runner` / `dart analyze` / network. Not a
  hang source.
- `lib/src/plugins/xray/xray_mock_scaffolder.dart` and
  `lib/src/plugins/xray/xray_deck_barrel_writer.dart` — text/regex + `File` I/O only; bounded
  work, no loops over unbounded inputs. Confirmed not the hang source.
- Confirmed NOT triggered: `lib/src/commands/build_command.dart` (build_runner/analyze) is not
  on this command path, so the timeout is not from a nested `dart analyze`/`build_runner`.

## Root Cause Hypothesis

Two contributing factors, Linux-specific:

1. **No child-process timeout in the test harness.** `runZfaSource` uses `Process.run` without
   a `timeout`. If a spawned `dart bin/zfa.dart` is slow to start or wedges (e.g. a stalled
   auto-`dart pub get`, a `dart` kernel/dILL cache miss forcing a full JIT compile of the
   large analyzer-backed CLI, or CPU starvation), the `Future` only resolves when the parent
   2-minute group timeout kills the test — producing the observed `TimeoutException`.
2. **Per-invocation CLI startup cost under parallel load.** Each subprocess re-runs
   `CliRunner._ensureInitialized()` → `PluginLoader.buildRegistry()`, which scans/loads the
   plugin set even though `xray mock`/`deck` never use it. With `dart test -j 4`, several CLI
   test files (`make_command_test.dart`, `app_shell_command_test.dart`,
   `initialize_dart_inplace_test.dart`, `issue_320_..._e2e_test.dart`, plus this file) spawn
   `dart bin/zfa.dart` concurrently. On a CPU-constrained Linux runner the JIT startup of a
   heavy package compounded across parallel processes pushes at least one invocation past 2
   minutes. The macOS run passes because its runner has more headroom / faster `dart` startup.

The platform split (fails Linux only, passes macOS) is the signature of resource contention +
missing fast-fail rather than a logic bug in the command. **Confidence: medium** (strong
circumstantial evidence from the code paths and the platform asymmetry; not yet reproduced by
running the suite locally).

## Proposed Remediation

**Preferred**:
1. Add a bounded child timeout to the test harness so a slow/hung `dart` spawn fails *fast*
   and surfaces the real cause instead of eating the whole 2-minute group window: give
   `Process.run` a `timeout:` (e.g. `Duration(minutes: 1)`) in
   `test/helpers/run_zfa_source.dart:46`, and on timeout throw an explicit, diagnostic error
   (`ProcessException`/`TimeoutException` naming the exact `zfa` args). This both prevents a
   single wedged process from blocking CI and makes the underlying slowness observable.
2. Reduce per-invocation CLI startup cost: make `CliRunner._ensureInitialized()` lazily build
   the plugin registry only when a command actually needs it (or skip `PluginLoader.buildRegistry()`
   for non-plugin subcommands such as `xray mock`/`deck`). This shrinks the JIT/startup tax paid
   by every spawned `dart bin/zfa.dart`, directly lowering the chance of blowing the timeout
   under parallel load.

**Alternatives**:
- Raise the per-test group timeout in `xray_mock_cli_test.dart:38` (e.g. to 4–5 min). Masks the
  problem, does not fix the slow spawn, and lengthens CI — not recommended as the only fix.
- Merge the two subprocess invocations or spawn a single long-lived `zfa` process / use the
  in-process `CliRunner.runCapturing` instead of `Process.run` for these assertions. Strong
  option but larger refactor of the hermetic-subprocess pattern the file deliberately uses
  (issue #506).

**Files likely to change**:
- `test/helpers/run_zfa_source.dart` (add `timeout:` to `Process.run`; diagnostic on timeout)
- `lib/src/cli/cli_runner.dart` (lazy / conditional plugin-registry init)
- `test/commands/xray_mock_cli_test.dart` (only if timeout tuning is accepted as part of the fix)

**Tests to add or update**:
- A regression/guard test asserting `runZfaSource` fails fast (within a child timeout) when the
  spawned process hangs — proving the hard 2-minute group timeout can no longer be silently
  consumed.
- Optionally a micro-benchmark asserting `zfa xray mock <Entity>` / `zfa xray deck ...`
  startup stays under a bounded budget, to catch future startup-cost regressions.

## Risks & Considerations

- **Lazy plugin-registry init** must still register all commands before `_runner.run(args)` is
  called; a command that depends on being present in `_ensureInitialized` must not regress.
  Verify `xray`, `make`, `app shell`, etc. still parse after the change.
- Adding a child timeout changes failure *modes*: a legitimately slow CI spawn will now fail
  with a shorter, clearer timeout rather than the group's 2-minute one. Tune the child timeout
  generously (e.g. 60–90s) so it catches only true wedges, not normal slow starts.
- This is a **CI-reliability / test-hang** defect, not a product correctness bug — no user-
  facing behavior is broken. Severity is driven by it blocking the Linux `dart test` suite.
- If the true trigger turns out to be a stalled auto-`dart pub get` in the child, the fix may
  instead belong in CI (pre-warm `.dart_tool` / ensure `dart pub get` ran) rather than in code.

## Open Questions

- [NEEDS CLARIFICATION: was the Linux runner CPU-constrained, and how many concurrent `dart`
  subprocess CLI tests ran during the failing run?]
- [NEEDS CLARIFICATION: was `dart pub get` already satisfied in `.dart_tool` on the failing
  Linux run, or could an auto-`pub get` in the child have stalled?]
- [NEEDS CLARIFICATION: does the same test also flake on macOS under heavier parallelism, or is
  the asymmetry purely Linux resource headroom?]
