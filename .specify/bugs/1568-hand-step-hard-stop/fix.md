# Fix: #1568 hand-step hard stop (park, not stop)

- **Slug**: 1568-hand-step-hard-stop
- **Status**: applied
- **Branch**: fix/1568-hand-step-park-not-stop
- **Date**: 2026-09-13

## Remediation

The planner's hand-step verdict (SPEC 1489 seam-cost forecast) is now a
run-level state: a make failure on a forecast seam behavior whose
transcript carries the still-failing-target-test shape parks the
behavior at its honest red, the pass continues with the remaining
behaviors, and the end-of-pass summary names the hand-steps.

### `lib/src/plugins/tdd/services/unit_contract_shape.dart`

- New `entityReturnSeamIndicesResolved` — the per-behavior seam verdict
  (indexes into the parallel declared-signature list);
  `countEntityReturnSeamsResolved` kept for existing callers.

### `lib/src/plugins/tdd/commands/run_driver_core.dart`

- `_entityReturnSeamForecast` (count) → `_entityReturnSeamIds` (id
  set), computed ONCE before the announce; the SPEC 1489 announce line
  uses its length.
- New arm in `_driveBehavior`'s failure chain (before the honest stop):
  `make` + `outcome=generation-error` + behavior in the forecast +
  `still fails after generation` in make's output → park (state keeps
  its honest red, reason recorded, loop continues). Two signals must
  agree; anything else keeps the generic stop.
- Phase-2a skips hand-stepped rows; phase-2b already skips non-green.
- End of pass: terminal branch naming the hand-steps with resume
  guidance, `stopped_at=<first>:hand` (feeds the existing #1308 journal
  violation shape), `handSteps` into `_finish`.
- `_finish` → journal violations gain `hand-step=<id> (<reason>)`;
  `RunDriverOutcome.handStepIds`; `summaryLine` gains the additive
  `hand_steps=N` token; `run_command._printSummary` passes it.

### Tests (new)

`test/plugins/tdd/commands/bug_1568_hand_step_park_not_stop_test.dart`
— 3 fast-tier fake-zfa tests (U-1568-1 the bug: park + U2 driven +
`hand_steps=1` + `stopped_at=U1:hand`; U-1568-2 real generation failure
on a seam keeps the generic stop; U-1568-3 the marker on a non-seam
never parks). Two additive fake-zfa make cases (`hand-step-red`,
`crash-no-marker`).

## Out of scope

Issue suggestion 2's `deferred`-style outcome TOKEN on make itself and
suggestion 1's dedicated `outcome=hand-step` token: the triage comment
narrows the fix to the run level, and the driver-side park delivers the
same observable behavior without changing make's machine contract.
