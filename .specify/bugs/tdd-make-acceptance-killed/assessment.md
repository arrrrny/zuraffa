# Bug Assessment: zfa tdd make subprocess killed (exit -9) for acceptance behaviors

- **Slug**: tdd-make-acceptance-killed
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/796
- **Verdict**: likely valid, needs reproduction
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd make` for acceptance behaviors (A1-A9) fails with `generation-error` because the underlying `zfa make <id> --no-entity` subprocess gets killed (exit -9 = SIGKILL, likely OOM or timeout). https://github.com/arrrrny/zuraffa/issues/796

## Symptom

`zfa tdd run` stops at A3:make with `generation-error` and `exit: -9` for the subprocess `zfa make a3 --no-entity`. Direct invocation of the same command prints `❌ No active plugins to run.` and completes normally, but the TDD loop reports a SIGKILL.

## Reproduction

1. `zfa setup --platforms=macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy any spec with acceptance behaviors (e.g. specs/004-dependency-injection/spec.md)
4. `zfa tdd plan 004-dependency-injection`
5. `zfa tdd run 004-dependency-injection`
   → **exit 1**: stops at A3:make with generation-error

[NEEDS CLARIFICATION: the exact exit code of the direct `zfa make a3 --no-entity` invocation — the issue shows the command completing with a message but does not state its exit code.]

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/make_command.dart` — the `zfa tdd make` command that invokes the pipeline runner for the behavior's generation plan.
- `lib/src/plugins/tdd/services/pipeline_runner.dart` — runs the plan steps; uses `TddTimeouts.defaultPipelineStep` per-step deadline and captures `exitCode` from the child result.
- `lib/src/plugins/tdd/services/tdd_timeout.dart` — the timeout wrapper that kills the child with SIGKILL (exit -9 on POSIX) when it outlives the deadline.
- `lib/src/commands/make_command.dart:498` — the actual `zfa make` command prints `❌ No active plugins to run.` and returns when `activePlugins.isEmpty`.

## Root Cause Hypothesis

The `--no-entity` path in `zfa make` reaches `activePlugins.isEmpty` (line 498) and prints an error message, but the TDD loop's subprocess invocation reports `exit: -9` (SIGKILL). Two hypotheses:

1. **Timeout kill (more likely)**: the subprocess hangs or takes too long before printing the message, and `tdd_timeout.dart` kills it with SIGKILL at the per-step deadline. The direct invocation completes because it's not subject to the TDD timeout wrapper.
2. **OOM kill**: the subprocess consumes too much memory and the OS kills it with SIGKILL.

The fact that spec 001 (app-bootstrap) completed all 21 behaviors while spec 004 (DI) fails at A3 make suggests the issue is specific to the DI spec's acceptance behaviors, not a general hang.

Confidence: medium.

## Proposed Remediation

**Preferred**: Make `zfa make <id> --no-entity` exit with a clear non-zero exit code and a helpful error message when no active plugins are found, so the TDD loop can classify it as a user-facing error rather than a crash. In `lib/src/commands/make_command.dart`, change the `activePlugins.isEmpty` branch from `print('❌ No active plugins to run.'); return;` to `print('❌ No active plugins to run.'); exit(1);` (or throw an exception that the caller catches).

**Alternative**: Have the TDD loop (`lib/src/plugins/tdd/commands/make_command.dart`) handle the "No active plugins" case gracefully — if the subprocess exits with this specific message, classify it as `unexpressible` or `skipped` rather than `generation-error`.

**Tests to add or update**:
- A test that invokes `zfa make <id> --no-entity` with no active plugins and asserts it exits with a non-zero code (not 0, not -9).
- A TDD test that runs the pipeline with a behavior whose generation plan has no active plugins and asserts the outcome is `unexpressible` or `skipped`, not `generation-error`.

## Risks & Considerations

- Changing the exit code of `zfa make` when no active plugins are found could break other callers that rely on exit 0 for this case.
- The TDD loop's per-step timeout (`TddTimeouts.defaultPipelineStep`) may need adjustment if the subprocess legitimately needs more time.
- If the root cause is OOM, the fix may need to be at the memory level rather than the exit code level.

## Open Questions

- [NEEDS CLARIFICATION: what is the actual exit code of `zfa make a3 --no-entity` when run directly (not through the TDD loop)?]
- [NEEDS CLARIFICATION: is the -9 from the TDD timeout wrapper (SIGKILL at deadline) or from an OS OOM kill?]
- [NEEDS CLARIFICATION: why does spec 001 complete all 21 behaviors while spec 004 fails at A3 make? What's different about the DI spec's acceptance behaviors?]