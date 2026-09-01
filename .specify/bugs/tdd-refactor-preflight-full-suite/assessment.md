# Bug Assessment: fix(tdd): refactor preflight is full dart test — fails when U3+ are still red

- **Slug**: tdd-refactor-preflight-full-suite
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/734
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd refactor` runs a preflight `dart test` (full suite) and refuses to proceed if any test is red. When phase 1 has pending U* behaviors (U3-U44), the suite has 3+ red tests, and the preflight fails for every behavior — blocking phase 2b refactor for ALL green behaviors (A1-A5, U1-U2), not just the ones whose own test passes.

Issue URL: https://github.com/arrrrny/zuraffa/issues/734

## Symptom

The refactor preflight runs the full suite and fails on any red test, even red tests in behaviors the run hasn't reached yet (U3-U44 pending stubs throwing `UnimplementedError`). This blocks refactor for already-green behaviors when the run stops early in phase 1.

## Reproduction

1. State: A1-A5 all green (composed), U1-U2 green, U3-U44 pending (not generated).
2. Run `zfa tdd run` — phase 2b refactor pass.
3. Observe `[run] A5 refactor -> not-green` because the full suite has U3+ stubs throwing `UnimplementedError`.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/refactor_command.dart:145-177` — **confirmed**. The preflight runs the full suite template loaded from `tdd-profile.md` via `runner.runSuite(suiteTemplate: …, workingDirectory: cwd)`. On `preflight.exitCode != 0` it refuses, names failing tests, and points to `zfa tdd make`. There is intentionally no `--skip-preflight` option (FR-002).
- `lib/src/plugins/tdd/commands/refactor_command.dart:8-10` — doc comment: "runs the full suite as the absolute preflight — refusing on any red (FR-001), with no `--skip-preflight` option (FR-002)."
- `lib/src/plugins/tdd/commands/run_command.dart:362-369` — **confirmed**. The phase 2b driver comment assumes "the suite is fully green" before running refactor per behavior. This assumption breaks when the run stops early (e.g. #731 false-positive at U2), leaving U3-U44 pending with `UnimplementedError` stubs.
- `specs/048-tdd-refactor/spec.md:148-152` — **confirmed**. FR-001: "`zfa tdd refactor` MUST run the full suite via the project's `tdd-profile.md` before any refactor pass, and MUST refuse (non-zero, failing tests named) when the suite is not green or cannot run." FR-002: no option to skip or weaken the preflight.

## Root Cause Hypothesis

There are two layers:

1. **Spec layer**: spec 048 FR-001 mandates a full-suite preflight for `zfa tdd refactor`. That contract is correct for a *standalone* refactor invocation on a complete feature — and the spec explicitly forbids weakening it (FR-002, no skip flag).

2. **Driver layer**: `run_command.dart` phase 2b invokes refactor *per behavior* inside a running loop where the suite is NOT guaranteed fully green — the run may have stopped early in phase 1, leaving later behaviors (U3-U44) pending with `UnimplementedError` stubs. The phase 2b comment (lines 362-368) assumes the run always reaches every behavior in phase 1 first; that assumption is false when the run stops early.

The conflict: the driver calls a command whose preflight contract (full-suite green) cannot be met in the driver's context. High confidence — both code paths and the spec text verified directly.

## Proposed Remediation

**Preferred**: Resolve the conflict at the driver layer without weakening spec 048 FR-001 for standalone invocations:

- In `run_command.dart` phase 2b, gate refactor per behavior on **that behavior's own test** being green, not the full suite. Concretely: before invoking refactor for a behavior, check that the behavior's test target (e.g. `test/tdd/<behavior>_test.dart`) exits 0; if it does, run refactor; if not, skip with a recorded reason (the behavior is not yet green).
- Keep `refactor_command.dart`'s full-suite preflight intact for standalone `zfa tdd refactor` (spec 048 FR-001 / FR-002 unchanged).
- Update the phase 2b comment in `run_command.dart` (lines 362-368) to reflect the per-behavior gate.

**Alternatives**:
- Add a `--behavior <id>` scope to `zfa tdd refactor` that runs only that behavior's test as the preflight. Trade-off: changes spec 048's FR-001 contract; requires a spec amendment.
- In phase 2b, skip refactor entirely for behaviors whose own test is red and rely on a final full-suite refactor pass at feature end. Trade-off: loses per-behavior refactor evidence.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/run_command.dart` (phase 2b gate logic + comment)
- `test/plugins/tdd/run_command_test.dart` (phase 2b scenario)

**Tests to add or update**:
- Phase 2b refactor proceeds for A1-A5 + U1-U2 after a run that stopped at U2, even though U3+ are red.
- Phase 2b skips refactor for a behavior whose own test is red.
- Standalone `zfa tdd refactor` still refuses on a red full suite (regression for spec 048 FR-001).

## Risks & Considerations

- Per-behavior gating in the driver weakens the "whole suite is green" guarantee *for the driver's refactor pass only*; standalone refactor keeps the full-suite contract. This divergence must be documented.
- If spec 048 is later amended to allow scoped preflight, the driver's per-behavior gate and the standalone full-suite path should converge.
- The run's early-stop cause (#731 false-positive) is a separate bug; this fix does not address it — it makes the loop resilient to early stops.

## Open Questions

- [NEEDS CLARIFICATION: Should the driver's per-behavior gate be a temporary resilience measure, or a permanent contract change to spec 048?]
- [NEEDS CLARIFICATION: Does a skipped refactor (own test red) still count as "not DONE" for the feature, or is it deferred to a later pass?]