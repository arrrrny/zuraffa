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
  set); the SPEC 1489 announce line uses its length.
- New arm in `_driveBehavior`'s failure chain (before the honest stop):
  `make` + `outcome=generation-error` + the forecast contains the
  behavior + `still fails after generation` in make's output → park
  (state keeps its honest red, reason recorded, loop continues). Two
  signals must agree; anything else keeps the generic stop.
- Phase-2a skips hand-stepped rows; phase-2b already skips non-green.
- End of pass: terminal branch naming the hand-steps with resume
  guidance, `stopped_at=<first>:hand`, `handSteps` into `_finish`.
- `_finish` → journal violations gain `parked-hand-step=<id> (<reason>)`;
  `RunDriverOutcome.handStepIds`; `summaryLine` gains the additive
  `hand_steps=N` token; `run_command._printSummary` passes it.

### Review follow-ups (PR #1619 review)

- **Lazy forecast resolve.** The park gate resolved the seam ids once,
  before the announce — i.e. before `_runEntityPhaseZero` created the
  pass's declared entities, so a behavior whose entity this same pass
  generated stayed "seam" for the whole run. The arm now resolves the
  forecast itself, on the failure path (after the marker check), so the
  registry read is fresh; the announce keeps its own output-only read.
  The forecast id set is no longer threaded through `_driveBehavior`.
- **The park record survives every stop path.** The three in-loop
  `if (result.stop != null) return _finish(...)` sites (phase 1, 2a, 2b)
  now forward `handSteps:` — previously a pass that parked U1 and later
  stopped for U2 reported `handStepIds == []`, dropping both
  `hand_steps=N` and the journal line.
- **A park no longer prescribes the #1308 remedy.** `_finish`'s
  `_handStepViolationFor` lookup stands down when the stopped behavior is
  itself parked (that helper can only emit the #1323/#1373/#1411/#1308
  vocabularies, none of which applies to an entity-return park). A
  `:hand` stop for any OTHER behavior keeps its remedy.
- **Distinct journal token.** The park rides `parked-hand-step=<id>
  (<reason>)` so `hand-step=<id>:hand — <sentence>` stays a single
  machine-greppable grammar.
- **The engine lane and `--json` carry the token too.**
  `run_engine_command.dart` forwards `handStepIds: outcome.handStepIds`
  (the engine lane is the only lane that can park), and
  `run_command._printSummary` records `details['hand_steps']` when
  non-empty.

### Tests (new)

`test/plugins/tdd/commands/bug_1568_hand_step_park_not_stop_test.dart`
— 4 fast-tier fake-zfa tests (U-1568-1 the bug: park + U2 driven +
`hand_steps=1` + `stopped_at=U1:hand` + the park's own journal token and
NOT the #1308 remedy; U-1568-2 real generation failure on a seam keeps
the generic stop; U-1568-3 the marker on a non-seam never parks;
U-1568-4 review fix: park U1, then a REAL generation error on U2 — the
summary and the journal still record the parked U1). Two additive
fake-zfa make cases (`hand-step-red`, `crash-no-marker`). The two
review-fix assertions were proven RED against the pre-fix driver.

## Out of scope

Issue suggestion 2's `deferred`-style outcome TOKEN on make itself and
suggestion 1's dedicated `outcome=hand-step` token: the triage comment
narrows the fix to the run level, and the driver-side park delivers the
same observable behavior without changing make's machine contract.
