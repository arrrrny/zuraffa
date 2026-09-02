# Bug Assessment: fix(tdd): #734/#743 partial fix — refactor preflight still calls runSuite (full dart test)

- **Slug**: tdd-refactor-preflight-full-suite
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/754
- **Verdict**: valid — #743's fix was incomplete; the refactor preflight was not actually changed
- **Severity**: high

## Report (verbatim or summarized)

Issue #734 (refactor preflight full-suite false negative) was reportedly fixed via #743 (commit `13172c00`), but the fix did NOT change `refactor_command.dart` line 181 — the preflight still calls `runner.runSuite()` which runs `dart test` for the whole project. U8:make is green but U8:refactor fails the full-suite preflight because 36 U* stubs are still `UnimplementedError`. The fix that landed was either in a different file or the per-behavior logic exists but isn't reached in the run driver's "make succeeded, now refactor" path. https://github.com/arrrrny/zuraffa/issues/754

## Symptom

The refactor preflight runs `dart test` (full suite) and fails when ANY test is red — including un-stubbed behaviors (U9+) the run hasn't reached yet. The make step correctly classifies the current behavior as green, but the refactor step then fails the full-suite preflight.

## Reproduction

1. State: 12 done, U8 green (test passes), 36 pending (U9+ not yet generated).
2. `zfa tdd run 004-cloud-agent-task-dispatch`
3. Observe: `[run] U8 make -> green`, then `[run] U8 refactor -> not-green`, preflight exit: 1.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/refactor_command.dart:181` — **confirmed stale**. `final preflight = await runner.runSuite(...)` still calls full suite.
- `lib/src/plugins/tdd/commands/refactor_command.dart:85` — explicit comment "there is INTENTIONALLY no --skip-preflight option".
- `lib/src/plugins/tdd/commands/run_command.dart` — the "make succeeded, now refactor" path invokes the refactor command whose preflight still runs the full suite.

## Root Cause Hypothesis

Two layers:

1. **#743 claimed to fix #743 but didn't touch `refactor_command.dart:181`** — the code path the run driver actually exercises is unchanged. This is the 5th fix-incomplete in the session; pattern: fix gets merged but the exercised path is unchanged.
2. **Spec vs driver conflict**: spec 048 FR-001 mandates full-suite preflight for standalone `zfa tdd refactor`. But the run driver's phase 2b invokes refactor per-behavior inside a loop where the suite is NOT guaranteed green (run may stop early in phase 1). The driver calls a command whose preflight contract cannot be met in the driver's context.

The conflict is the same as #734's assessment, but #754's key finding is that #743's fix landed in the wrong place — it didn't update `refactor_command.dart` at all.

## Proposed Remediation

**Preferred** (same as #734, now targeting the correct file):

- In `run_command.dart` phase 2b, gate refactor per behavior on **that behavior's own test** being green, not the full suite. Before invoking refactor for a behavior, check that `test/tdd/<behavior>_test.dart` exits 0; if not, skip with a recorded reason.
- Keep `refactor_command.dart`'s full-suite preflight intact for standalone `zfa tdd refactor` (spec 048 FR-001 / FR-002 unchanged).
- Update the phase 2b comment in `run_command.dart` to reflect the per-behavior gate.

**Key difference from #734**: verify that the fix actually lands in `refactor_command.dart` or `run_command.dart` — #743's failure mode was a fix that didn't touch the exercised path.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/run_command.dart` (phase 2b gate logic + comment)
- `test/plugins/tdd/run_command_test.dart` (phase 2b scenario)

**Tests to add or update**:
- Phase 2b refactor proceeds for U8 after a run where U8 is green but U9+ are red.
- Phase 2b skips refactor for a behavior whose own test is red.
- Standalone `zfa tdd refactor` still refuses on a red full suite (regression for spec 048 FR-001).

## Risks & Considerations

- This is a follow-up to #734/#743 — the previous fix was incomplete. Verify the new fix actually lands in the code path the run driver exercises.
- Per-behavior gating in the driver weakens the "whole suite is green" guarantee for the driver's refactor pass only; standalone refactor keeps the full-suite contract.
- The run's early-stop cause is a separate bug; this fix makes the loop resilient to early stops.
- **STOP-ON-ROADBLOCK** applies: this is the 5th fix-incomplete. If the gap blocks the workflow, stop and report per zuraffa/AGENTS.md.

## Open Questions

- [NEEDS CLARIFICATION: where did #743's fix actually land if not in refactor_command.dart? Identify the real file to avoid repeating the pattern.]
- [NEEDS CLARIFICATION: Should the driver's per-behavior gate be temporary resilience or a permanent contract change?]
