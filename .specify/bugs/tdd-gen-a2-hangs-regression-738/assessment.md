# Bug Assessment: [BUG] zfa tdd gen hangs on second behavior (regression from #738)

- **Slug**: tdd-gen-a2-hangs-regression-738
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/744
- **Verdict**: likely valid, needs reproduction
- **Severity**: critical

## Report (verbatim or summarized)

After fix #738 (regression check compares only current behavior's test), `zfa tdd gen A2` hangs indefinitely on a fresh project. The command does not complete and must be killed with SIGKILL. Confirmed on v6.1.0 rebuilt with fixes #735, #738, #739.

Issue URL: https://github.com/arrrrny/zuraffa/issues/744

## Symptom

`zfa tdd gen A2` (the second behavior in a fresh feature) hangs indefinitely after fix #738. `zfa tdd run` reports `[run] A2 gen -> error` and stops.

## Reproduction

1. `zfa setup --platforms=macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy spec, run `zfa tdd plan 001-app-bootstrap`
4. `zfa tdd gen A1 --feature 001-app-bootstrap` (works)
5. `zfa tdd gen A2 --feature=001-app-bootstrap` → hangs indefinitely (killed with SIGKILL after 20s)

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/gen_command.dart:112-190` — **confirmed**. `gen` resolves the behavior, runs `registry.preflight`, writes the test+subject pair, and appends the registry record. The command itself does NOT spawn any subprocess — it is pure file I/O + registry. So the hang is NOT inside `gen_command.dart` itself.
- `lib/src/plugins/tdd/services/artifact_registry.dart:98-171` — **confirmed**. `preflight` loads records via `_loadRecords()`, checks for a prior record by `behaviorId`, validates paths, and returns ownership. This is synchronous file reads — no subprocess, no hang risk here.
- `lib/src/plugins/tdd/commands/make_command.dart:593-625` — **confirmed**. Fix #738 added `_regressionsAttributableToThisMake` (line 615) and the suite-guard regression scoping logic (lines 425-482). The commit `0f8ac301` modified `make_command.dart` (+114 lines). The regression check runs the full suite baseline and guard per make invocation.
- `lib/src/plugins/tdd/commands/run_command.dart:599-720` — **confirmed**. `_driveBehavior` spawns each step as a subprocess and awaits `result.outcome`. A hanging step (e.g. `make` running the full suite) blocks the run loop.

## Root Cause Hypothesis

The issue attributes the hang to fix #738. The #738 commit (`0f8ac301`) modified `make_command.dart` to scope the regression verdict to the current behavior's own test file. The `gen` command itself does not spawn subprocesses — it is pure file I/O. So the hang is most likely in a **subprocess spawned by the run driver** (e.g. `make` running the full-suite baseline/guard), not in `gen` directly.

However, the issue reports `zfa tdd gen A2` hanging directly (not via `zfa tdd run`). This suggests one of:
1. `gen` now transitively invokes something that hangs (e.g. a new dependency on `make`'s regression check, or a shared state file that locks).
2. The hang is in a shared resource (e.g. `artifacts.json` lock, a temp directory, or a process left running by A1's `make` that A2's `gen` waits on).
3. The issue's "hang" is actually a `zfa tdd run` hang where the driver is stuck waiting on A2's `make` step (which runs the full suite), and the user killed the whole process.

Medium confidence: the #738 code path is verified, but the exact hang mechanism is unclear because `gen` itself is pure file I/O and the issue's reproduction is ambiguous about whether the hang is in `gen` directly or in the run driver's subprocess spawn.

## Proposed Remediation

**Preferred**: Add a per-command timeout to every TDD subprocess invocation (see #742's assessment for the full list of affected files). This is the systemic fix that prevents indefinite hangs regardless of the trigger. Specifically:

1. In `runner.dart` `runSingle` and `runSuite`, wrap `Process.run` with a `timeout` (e.g. `Duration(minutes: 5)` for single tests, `Duration(minutes: 15)` for the full suite).
2. In `pipeline_runner.dart` `runPlan`, add a per-step timeout.
3. In `run_command.dart` `_driveBehavior`, add a timeout on the step spawn.
4. When a timeout fires, kill the process, return a `runnerError`/timeout outcome, and exit non-zero (misfire-stop).

**Secondary**: Investigate whether fix #738 introduced a shared-state or locking issue that causes A2's `gen` to block. Check `artifacts.json` access, temp directory creation, and any new synchronous dependency between `gen` and `make`.

**Files likely to change**:
- `lib/src/plugins/tdd/services/runner.dart` (timeout on `runSingle`/`runSuite`)
- `lib/src/plugins/tdd/commands/run_command.dart` (timeout on step spawn)
- `lib/src/plugins/tdd/services/pipeline_runner.dart` (per-step timeout)
- `lib/src/plugins/tdd/services/artifact_registry.dart` (if a locking issue is found)

**Tests to add or update**:
- A hanging subprocess is killed after the timeout and the command exits non-zero with a `runnerError`/timeout classification.
- `zfa tdd gen A2` completes in <30s on a fresh project (regression test for #738).

## Risks & Considerations

- A timeout that is too short will cause spurious failures on slow CI machines; the default must be generous and overridable.
- Killing a `dart test` subprocess mid-run may leave partial state; the run's resume semantics must account for this.
- This bug is a regression from #738; the timeout fix alone may not address the root cause if #738 introduced a genuine blocking issue (e.g. a deadlock in shared state).

## Open Questions

- [NEEDS CLARIFICATION: Does `zfa tdd gen A2` hang directly, or does `zfa tdd run` hang while driving A2's `make` step (which runs the full suite)?]
- [NEEDS CLARIFICATION: Did fix #738 introduce any new shared-state access (e.g. `artifacts.json` locking) between `gen` and `make`?]