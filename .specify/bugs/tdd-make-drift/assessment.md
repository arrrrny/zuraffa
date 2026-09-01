# Bug Assessment: [BUG] zfa tdd make: drift on already-green test breaks run loop

- **Slug**: tdd-make-drift
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/694
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

`zfa tdd make` reports `outcome=drift` when the target test is already passing from a prior run. This breaks the `zfa tdd run` loop because the run-state thinks the behavior is `red` but the test is actually green.

Reproduction:
1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy spec, run `zfa tdd plan 001-app-bootstrap`
4. `zfa tdd run 001-app-bootstrap --zfa-bin ~/.local/bin/zfa` (runs A1-A9, some get made green)
5. Re-run `zfa tdd run 001-app-bootstrap --zfa/bin ~/.local/bin/zfa`
   → **exit 1**: `behavior=A9 step=make outcome=drift`

Workaround: Reset the subject stub to `throw UnimplementedError` before re-running, or delete `run-state.json` to force a fresh run.

See https://github.com/arrrrny/zuraffa/issues/694

## Symptom

On a second `zfa tdd run` invocation, `make` exits with `outcome=drift` and the run loop stops. The test is actually green, but the run-state persisted `red` across invocations (typically after a crashed or interrupted prior run that successfully made the test green but did not persist the updated state).

## Reproduction

1. Set up a TDD project with `zfa setup` and `zfa tdd init`
2. Run `zfa tdd plan` and `zfa tdd run` to make some behaviors green
3. The prior run crashes or the state file is not persisted after a successful make
4. Re-run `zfa tdd run` — behavior is still `red` in state, `_stepsFor(red)` re-enters at `make`
5. `make` runs the drift check, finds the test green, exits with `outcome=drift` and exit 1
6. Run loop stops; `[run] A9 make -> drift` printed

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/make_command.dart:218–237` — the drift check block (`_hasCertifiedRed` at line 694): runs the target test before generation; if `exitCode == 0 && startedProcess`, declares `drift` and exits non-zero. No distinction is made between "green because of a prior successful `make`" vs "green because of hand-written code". The state file is not consulted.

- `lib/src/plugins/tdd/services/cycle_evidence.dart` — `CycleEvidence` class with `greenEvidence()` and `redEvidence()` methods that scan `tdd/cycle-log.md` for green/red entries. Available for use in `make_command.dart` after `featureDir` is resolved.

- `lib/src/plugins/tdd/commands/run_command.dart:457–469` — `_stepsFor(state)` maps `BehaviorState.red → ['make']` (skipping verify-red). A behavior stuck at RED after a successful make causes `make` to be re-entered on the next run, triggering the drift check unconditionally.

## Root Cause Hypothesis

**High confidence.**

The `drift` outcome in `make_command.dart` (FR-003 / US2.AC3) was designed to catch hand-implemented code — tests that pass before any `zfa make` ever generated the implementation. It does this by re-running the test and refusing if it passes.

The bug occurs in the re-entry scenario: if `make` succeeded in a prior run, it wrote green evidence to `tdd/cycle-log.md` AND called `run_state_store.save()` to flip the behavior to GREEN. But if the process crashed or was killed between the green evidence write and the state save, the cycle-log has the green entry but the state file still shows RED. On the next `run` invocation, `_stepsFor(red)` re-enters at `make` (skipping `verify-red` which is already certified), and `make`'s drift check finds the test green — correctly noting it is not a fresh-red test, but incorrectly treating it as hand-written drift rather than a recovered already-green behavior.

The `make` command has no access to cycle-log evidence at the drift-check point, so it cannot distinguish the two cases.

## Proposed Remediation

**Preferred**: Add a green-evidence check to the drift block in `make_command.dart`. Before declaring `drift`, consult the feature's `cycle-log.md` for an existing `kind: green` entry for this behavior. If one exists, the test is green from a prior successful `make` — update the run-state to `green`, print a brief note, and exit 0 (no regeneration needed). Only report `drift` when no prior green evidence exists (true hand-written code scenario).

**Alternatives**:
- Have `make` consult the state file's `behavior_states` map directly (requires passing the state store into `make_command.dart`). More invasive, and state may lag behind evidence in crash scenarios.
- Auto-recover in `run_command.dart` by re-reading cycle-log evidence before re-entering `make` and demoting a RED state to GREEN when green evidence exists. Fixes the symptom but not the root cause in `make`.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/make_command.dart` — add green-evidence check in the drift block; if evidence exists, return `MakeOutcome.green` instead of `MakeOutcome.drift`
- `test/plugins/tdd/make_command_test.dart` — update the `U25/A6` drift test to verify that a green test with prior green cycle-log evidence exits 0 (green), not drift

**Tests to add or update**:
- A new test: "green test with prior green cycle-log evidence → green outcome, no regeneration" (the recovery path)
- Existing `U25/A6` test in `make_command_test.dart` seeds a green test with NO green cycle-log entry and expects drift — this behavior is correct (hand-written) and should be preserved

## Risks & Considerations

- The fix narrows the `drift` check to only fire when no green evidence exists. This is correct — if green evidence exists, `make` ran successfully before, and the behavior is legitimately green.
- The `_stepsFor(red)` re-entry at `make` is correct behavior (verify-red already certified); the bug is that `make` cannot recover from its own successful prior run.
- No API changes; purely additive evidence check.

## Open Questions

- [RESOLVED: The root cause is that `make` doesn't check cycle-log evidence before declaring drift. The fix is to add that check.]
- [RESOLVED: The scenario in the existing `U25/A6` test (green test, no green cycle-log entry) is hand-written code and should still report drift — the fix preserves this by only skipping drift when green evidence IS found.]
