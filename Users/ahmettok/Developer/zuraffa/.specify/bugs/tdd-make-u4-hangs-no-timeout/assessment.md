# Bug Assessment: [BUG] zfa tdd make U4 hangs indefinitely (no timeout)

- **Slug**: tdd-make-u4-hangs-no-timeout
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/742
- **Verdict**: likely valid, needs reproduction
- **Severity**: high

## Report (verbatim or summarized)

The issue title is `[BUG] zfa tdd make U4 hangs indefinitely (no timeout)`. The issue body is empty — no reproduction steps, no stack trace, no expected behavior. The title alone states that `zfa tdd make U4` hangs indefinitely because there is no timeout.

Issue URL: https://github.com/arrrrny/zuraffa/issues/742

## Symptom

`zfa tdd make U4` (and likely every other `zfa tdd make <behavior>` invocation) can hang indefinitely when the spawned `dart test` process never terminates — there is no timeout on any subprocess invocation.

## Reproduction

[NEEDS CLARIFICATION: the issue body is empty — no reproduction steps were provided. The title implies `zfa tdd make U4` hangs; the exact trigger (a hanging test, a deadlock, a missing `--timeout` flag) is unknown.]

## Suspected Code Paths

- `lib/src/plugins/tdd/services/runner.dart:286-308` — **confirmed**. `runSingle` invokes `Process.run(executable, args, workingDirectory: …)` with no `timeout` parameter. If the spawned `dart test` hangs, the runner awaits forever.
- `lib/src/plugins/tdd/services/runner.dart:325-346` — **confirmed**. `runSuite` invokes `Process.run(executable, args, workingDirectory: …)` with no timeout. Same indefinite-hang risk for the full-suite baseline and guard.
- `lib/src/plugins/tdd/services/pipeline_runner.dart:97-104` — **confirmed**. `runPlan` invokes `Process.run(entrypoint.executable, args, workingDirectory: …)` with no timeout. A hanging `zfa build` or `zfa tdd func` step blocks the pipeline forever.
- `lib/src/plugins/tdd/services/corpus_step_runner.dart:222-225` — **confirmed**. Corpus driving uses `Process.run` with no timeout.
- `lib/src/plugins/tdd/services/refactor_passes.dart:100-103` — **confirmed**. `DefaultProcessExecutor.run` uses `Process.run` with no timeout.
- `lib/src/plugins/tdd/services/mutation_auditor.dart:365-368` — **confirmed**. The mutation preflight uses `Process.run('dart', ['test', ...])` with no timeout.

## Root Cause Hypothesis

None of the TDD subprocess invocations pass a `timeout` to `Process.run`. `Process.run` without a timeout awaits the process indefinitely — if the spawned `dart test` (or `zfa build`, `zfa tdd func`) hangs for any reason (deadlock, infinite loop, a test that never completes, a missing `--timeout` flag on a long-running test), the runner hangs forever. This is a systemic absence of timeouts across the TDD subsystem, not a single-code-path bug. Medium confidence: the code paths are verified directly; the exact trigger for the U4 hang is unknown because the issue body is empty.

## Proposed Remediation

**Preferred**: Add a configurable per-command timeout to every TDD subprocess invocation, with a generous default (e.g., 10 minutes for the full suite, 2 minutes for a single test) and a `--timeout <minutes>` flag on `zfa tdd run` / `zfa tdd make` to override it. When a timeout fires:

- Kill the spawned process (`Process.kill(pid)`).
- Return a `runnerError` / `timeout` outcome (the `red_classification.dart` model already has a `runnerError` bucket for "infrastructure failure, timeout, blended or unexplained run").
- Print a clear message naming the behavior, step, and command, and exit non-zero (misfire-stop).

**Files likely to change**:
- `lib/src/plugins/tdd/services/runner.dart` (`runSingle`, `runSuite`)
- `lib/src/plugins/tdd/services/pipeline_runner.dart` (`runPlan`)
- `lib/src/plugins/tdd/services/corpus_step_runner.dart`
- `lib/src/plugins/tdd/services/refactor_passes.dart` (`DefaultProcessExecutor`)
- `lib/src/plugins/tdd/services/mutation_auditor.dart` (preflight)
- `lib/src/plugins/tdd/commands/run_command.dart` / `make_command.dart` (timeout flag plumbing)

**Tests to add or update**:
- A hanging test process is killed after the timeout and the command exits non-zero with a `runnerError`/timeout classification.
- The default timeout does not fire for a normally-completing test.
- The `--timeout` flag overrides the default.

## Risks & Considerations

- A timeout that is too short will cause spurious failures on slow CI machines; the default must be generous and overridable.
- Killing a `dart test` subprocess mid-run may leave partial state (generated files, build cache); the run's resume semantics must account for this (re-run from the failed step).
- Timeouts change the failure model: a timed-out behavior is no longer "red" (unresolved) — it must be classified distinctly so the run driver does not treat it as a certified red.

## Open Questions

- [NEEDS CLARIFICATION: What is the exact trigger for the U4 hang — a specific test that never completes, a deadlock, or a missing `--timeout` flag on a long-running test?]
- [NEEDS CLARIFICATION: What should the default timeout be (per-step vs per-behavior vs per-feature)?]
- [NEEDS CLARIFICATION: Should timeouts be enforced at the `Process.run` level (kill the process) or at the command level (pass `--timeout` to `dart test`)?]