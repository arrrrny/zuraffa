# Bug Assessment: zfa tdd make: drift on already-green test breaks run loop

- **Slug**: zfa-tdd-make-drift-on-already-green-test
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/694
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

`zfa tdd make` reports `outcome=drift` when the target test is already passing from a prior run. On re-running `zfa tdd run`, the loop stops at the first already-green behavior with `behavior=A9 step=make outcome=drift`, preventing later behaviors from running. Reported by arrrrny; no comments.

## Symptom

When `zfa tdd run` is re-run on a feature with one or more behaviors whose tests are already green from a prior run, `zfa tdd make` detects the green test (drift check at FR-003) and reports `outcome=drift`, which causes `run_command.dart` to stop the entire loop. The run-state persists with the behavior stuck at `red` while the test is green, creating a permanent mismatch.

## Reproduction

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy spec, run `zfa tdd plan 001-app-bootstrap`
4. `zfa tdd run 001-app-bootstrap --zfa-bin ~/.local/bin/zfa` (runs A1–A9; some behaviors go green)
5. Re-run `zfa tdd run 001-app-bootstrap --zfa-bin ~/.local/bin/zfa`
   → **exit 1**: `behavior=A9 step=make outcome=drift`

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/make_command.dart:218–237` — Drift check: runs the target test before generation; if `exitCode == 0 && startedProcess`, emits `outcome=drift` and exits non-zero. This is the correct detection logic, but the exit code feeds back into the run loop incorrectly.
- `lib/src/plugins/tdd/commands/run_command.dart:629–672` — Failure path for step results: when `result.success == false`, it checks for `unexpressible` deferral (lines 640–646) but has no special case for `drift`. All other non-zero outcomes fall through to "honest stop" (line 652–672), which advances to the **current** state (`state`) and stops the loop.
- `lib/src/plugins/tdd/commands/run_command.dart:653` — `updated = updated.advance(row.id, state);` — on drift, advances to the pre-existing `red` state (from `verify-red`), leaving the behavior at `red` despite the test being green.
- `lib/src/plugins/tdd/models/run_state.dart:32–42` — `advance()` always writes `newState` verbatim; no special handling for `drift`.

## Root Cause Hypothesis

**Confidence: high.**

The `run_command.dart` failure path (line 652–672) has special-case logic for `unexpressible` that defers the step without stopping the loop. The `drift` outcome is not handled specially, so it falls through to the "honest stop" branch, which:

1. Calls `updated.advance(row.id, state)` — the current `state` is `BehaviorState.red` (from the prior `verify-red`), so the behavior stays at `red`.
2. Saves the stale state to `run-state.json`.
3. Returns `stop: stopped`, halting the entire run loop.

The behavior is now permanently stuck at `red` even though its test is green. On every subsequent run, the drift check will re-fire and stop the loop again.

## Proposed Remediation

**Preferred**: Add a `drift`-specific branch in `run_command.dart` alongside the existing `unexpressible` deferral (around line 640), that:
1. Advances the behavior to `BehaviorState.green` (using `_maxState(state, _targetStateFor('make'))` — since `make`'s target state is `green`).
2. Saves the updated state.
3. Prints a note that the behavior was auto-marked green from drift detection.
4. **Does not stop the loop** — continues to the next behavior.

This mirrors the `unexpressible` deferral pattern but results in a permanent (non-deferred) state advancement.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/run_command.dart` — add `drift` branch at the failure-path deferral point (after line 646)

**Tests to add or update**:
- `test/plugins/tdd/make_command_test.dart` — `U25/A6` test already covers the standalone drift reporting behavior; extend or add an integration-level test that exercises `zfa tdd run` with a pre-existing green behavior to verify the loop continues.
- Add a scenario test in `test/plugins/tdd/scenarios/` that seeds a run-state with a `red` behavior whose test is green, then asserts that `zfa tdd run` does **not** stop and advances that behavior to `green`.

## Risks & Considerations

- The `drift` outcome's primary purpose (detecting hand-implemented code) is correct and must be preserved. The fix should not suppress the `drift` reporting or the non-zero exit from `make`; it only changes how `run_command.dart` reacts to it.
- Advancing to `green` on drift is safe: if the test passes, the behavior is genuinely green regardless of whether it was made by `make` or hand-written. The TDD contract is satisfied either way.
- No migration or schema changes needed; `BehaviorState.green` is already a valid state value.

## Open Questions

- None remaining after analysis.
