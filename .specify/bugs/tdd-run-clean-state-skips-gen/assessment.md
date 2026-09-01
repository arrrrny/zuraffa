# Bug Assessment: zfa tdd run on clean state goes straight to make — skips gen

- **Slug**: tdd-run-clean-state-skips-gen
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/720
- **Verdict**: valid
- **Severity**: high

## Report

`zfa tdd run` on a clean state skips `gen` and `verify-red` and goes straight to `make`, failing with "no gen artifacts". The run should start with `gen`.

## Symptom

Clean state → `[run] A1 make -> runner-error` — "no gen artifacts". Run stops at the first behavior.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/run_command.dart:299` — `_stepsFor(state, inFlightStep)` returns only `make` for a behavior with no gen artifacts but a prior `red` state.
- `lib/src/plugins/tdd/commands/run_command.dart` — `inFlightBehaviorId` / `inFlightStep` resume logic.

## Root Cause Hypothesis

When run-state is missing/stale, the driver's resume logic (`_stepsFor`) falls through to `make` instead of starting at `gen`. The `_stepsFor` function returns steps based on `BehaviorState` and `inFlightStep`, but a clean state with residual `red` evidence (from a prior interrupted run that never wrote `inFlight`) causes it to skip `gen`/`verify-red`. Confidence: **high** — the reproduction is deterministic.

## Proposed Remediation

Ensure that when `inFlightStep` is null/empty AND the behavior has no gen artifacts (no test/subject files), the driver starts at `gen` regardless of the `BehaviorState`. The `_stepsFor` logic should check for the presence of gen artifacts, not just the state claim.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/run_command.dart`

**Tests to add or update**:
- Clean `zfa tdd run` from empty state → produces `A1 gen -> ok`, `A1 verify-red -> certified`, `A1 make -> ...` in order.
- Interrupted run resumed from fresh wipe → starts with `gen` for the first behavior with no artifacts.

## Risks & Considerations

- This interacts with the #682 fix (symmetric promotion) — ensure a clean state with no evidence still starts at `gen`.
- The artifact-existence check must be robust (check both `test/tdd/` and `lib/tdd/` or wherever gen artifacts land).

## Open Questions

- None blocking.