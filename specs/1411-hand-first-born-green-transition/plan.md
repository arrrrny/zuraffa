# Plan — Spec 1411 hand-first born-green transition

**Branch**: `feat/1411-hand-first-born-green-transition` | **Date**: 2026-09-11 | **Spec**: [spec.md](./spec.md)

## Technical Context

- **Surface**: make's red-certification gate
  (`lib/src/plugins/tdd/commands/make_command.dart`) + the run driver's
  stop messaging (`lib/src/plugins/tdd/commands/run_driver_core.dart`)
  + the driver's step contract grading
  (`lib/src/plugins/tdd/services/step_runner.dart`) + make's outcome
  vocabulary (`lib/src/plugins/tdd/models/generation_plan.dart`).
- **Key concepts**: make red-certification gate; born-green hand
  transition (`--born-green`, the no-prior-red analogue of verify-red's
  `--re-certify` #1162); cycle-log red evidence precondition;
  `U<n>:hand` header detection (the machine-greppable attestation token
  `zfa:tdd: <id>:hand`, sibling of `zfa:tdd: scaffolded` /
  `zfa:tdd: vacuous-guard`); the #1036 placeholder-subject class;
  the #694/#741 skip-transition evidence pattern.
- **Hard constraints honored**: no change to the core engine cycle, the
  gen pipeline, verify-red's logic, or the cycle-log format. The new
  green evidence entry renders through the existing `CycleLogEntry`
  fields (`- evidence:` note, empty `generation:` block, zero suite
  numbers).

## Approach

1. **New service** `lib/src/plugins/tdd/services/born_green.dart`:
   `handStepHeader(id)` (the exact attestation line) and
   `contentCarriesHandStepHeader(content, id)` (case-insensitive
   content-keyed probe).
2. **make**: `--born-green` flag; the precondition's refusal gains the
   born-green OFFER when the marker is absent + the header is present;
   a new step-3b' transition block (after the 3b scaffolded refusal, so
   scaffolded shapes stay owned upstream) runs the gate shape
   safe-failure-first (vacuous content → `vacuous-green`; un-attested →
   `not-certified-red`; placeholder subject → `vacuous-green`; failing
   target → `not-certified-red` naming verify-red), then appends the
   green evidence and reports `outcome=born-green`, exit 0. With
   certified red present the flag is inert (red-first owns the flow).
3. **run driver**: in the make `not-certified-red` arm (after the #1373
   scaffolded hand-off), a #1411 hand-off arm keyed on
   `sawUnexpectedGreen` (this drive's passing-test signature) + the
   generated test's content state; stops at `<id>:hand` and names the
   exact recovery command. The content-keyed journal dispatch
   (`_handStepViolationFor`) gains the #1411 vocabulary for the
   attested shape.
4. **step contract**: `born-green` joins the terminal make success
   tokens (`green`/`skipped`/`green-with-failed-build`/`adopted`/
   `adopted-placeholder` precedent).

## Test strategy

`test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart`
(slow tier, real `dart test` subprocesses in the TddFixture for the make
block; the scripted fake zfa binary for the driver block):

- make block (real runner): B1 the full gate → exit 0, outcome=born-green,
  green evidence with the `- evidence:` note + `(none)` generation block;
  B2 no flag + attested → not-certified-red refusal naming `--born-green`;
  B3 flag + marker present → vacuous-green safe-failure; B4 flag +
  header absent → not-certified-red naming the exact header line; B5
  flag + failing test → not-certified-red naming verify-red; B6
  certified red + flag → the #694 skip transition (flag inert —
  backward compat).
- driver block (fake zfa): D1 attested hand-first catch-22 through
  `zfa tdd run` → the hand-off names `--born-green` +
  `stopped_at=U1:hand` + the journal violation; D2 un-attested → the
  exact header line is named; D3 red-first-shaped refusal (verify-red
  certified, make refuses) → the generic stop stands (no hand-off).

## Risks

- Double-certification via `--author --born-green` together: excluded by
  construction (the born-green block requires `!authorMode`; the flags
  are disjoint shapes).
- The arm firing on non-hand-first states: gated on `sawUnexpectedGreen`
  (an in-order red-first cycle never produces not-certified-red after an
  unexpected-green — the test passed, so no red could be certified).
