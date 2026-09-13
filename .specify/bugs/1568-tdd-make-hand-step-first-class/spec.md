# Spec: `tdd make` — first-class hand-step run state (issue #1568)

- **Slug**: 1568-tdd-make-hand-step-first-class
- **Source**: https://github.com/arrrrny/zuraffa/issues/1568
- **Siblings**: #1565 (scaffold-step refusal), #1544 (blocked contract parks forever), #1551 (acceptance compose hard-stop), #1308 (the hand-step vocabulary), SPEC 1489 (the seam forecast)
- **Status**: specified
- **Date**: 2026-09-14

## Problem

The planner announces hand-step behaviors UPFRONT — SPEC 1489 SC-4's seam
forecast prints `Seam cost: 10 of 14 unit behaviors will hand-step because
return is an entity.` — but `make` treats the SAME condition as
`generation-error` and stops the entire run. A feature with any hand-step
behavior can never drive its mechanical behaviors: the run stops at the first
hand-step, making the remaining unit/contract behaviors unreachable, and every
resume re-drives everything up to the same wall (#1544's blocked-contract
sibling).

Root cause — planner and driver disagree about the same behavior:

- **Planner**: predicts `hand-step` (entity-return contract subject — no
  mechanical implementation surface). The forecast counts exactly the
  unit-lane behaviors whose declared contract return is an entity-shaped type
  (`UnitContractShape.countEntityReturnSeamsResolved` → `!shape.scalarOutcome`).
- **Driver/`make`**: treats the same condition as `generation-error` and stops
  (fail fast).

The subject is a `gen` contract-derived stub
(`ScanSession scan() => throw UnimplementedError(...)`, issue #1259) with NO
generated implementation step for entity-returning contract subjects — unlike
the entity pipeline's `wire` + certified mock (#1498/#1500). Concretely, both
registry sub-shapes dead-end at make's post-generation red stop:

1. **Entity on disk (SPEC 1489 verbatim rendering)**: the paired test asserts
   the real outcome (`expect(result, isA<ScanSession>())`); make's plan skips
   the doomed `tdd func` step (#1565) and carries only the terminal `build`;
   the subject still throws; the make grades the honest red
   `generation-error`.
2. **Entity missing (the `Object?` degradation)**: `tdd func` DOES rewrite the
   stub, but its minimal body for a non-scalar declared return keeps the
   honest red (`throw UnimplementedError('implement per declared signature:
   ...')` — #920/#1259); the make again grades the honest red
   `generation-error`.

In both sub-shapes the mechanical generation did everything it could — the
remaining work is the DESIGNED author hand step (#1308's
`hand-step=<id>:hand` vocabulary) — yet the operator gets `generation-error`
for a condition the tool itself classified as expected work.

## Remediation (from the issue)

1. **First-class run state for hand-steps**: when the planner marked a
   behavior hand-step, `make` reports `outcome=hand-step` — a non-fatal
   verdict that leaves the behavior PENDING with its honest red, records the
   behavior in the run summary (`hand_steps=N`), and lets the run continue.
2. **Honest classification**: hand-step out of scope = a `deferred`-style
   transition (like `unexpressible` → `deferred (phase 2)`), NEVER
   `generation-error`.
3. **Report at run end**: name the hand-step behaviors in the final summary so
   the operator can implement them deliberately.

## Success criteria (measurable)

- **SC-1**: `zfa tdd make <id>` on a unit behavior whose declared contract
  returns an entity-shaped type, after the mechanical generation completes and
  the target test is still red, prints the machine summary
  `make: behavior=<id> outcome=hand-step feature=<f>` (never
  `outcome=generation-error`) and exits non-zero (no green evidence appended).
- **SC-2**: the make's stop message names the hand step (`<id>:hand`), the
  declared contract, and the exact remedy (implement the subject, re-run).
- **SC-3**: under `zfa tdd run`, a make `outcome=hand-step` is NON-FATAL: the
  behavior's state stays PENDING (honest red evidence intact), the run
  CONTINUES with the remaining behaviors, and the step event carries outcome
  `hand-step`.
- **SC-4**: the hand-step behavior id is PERSISTED in the feature's
  `tdd/run-state.json` (`hand_steps`), so a RESUME does not re-drive it — the
  resume prints a parked line and continues (the behavior keeps pending/red
  until the author implements the subject and re-runs make deliberately).
- **SC-5**: the run's final summary line carries `hand_steps=N` (N ≥ 1) and
  the end-of-run block lists the hand-step behavior IDs with the resume
  remedy.
- **SC-6**: mechanical behaviors AFTER a hand-step are reachable and drivable
  in the same run (a hand-step parked behavior does not stop the pass).
- **SC-7**: the fix is classification + propagation ONLY: the planner (the
  seam forecast), the entity pipeline (`wire` + certified mock), the analyze
  gate, and every existing refusal class keep their current surfaces
  (regression guards).

## Out of scope

- The planner's forecast (SPEC 1489) — untouched.
- The `wire` + certified mock entity pipeline (#1498/#1500) — untouched.
- The analyze gate (#942/#1407) — untouched.
- The #1308 vacuous-green stop (a DIFFERENT, already-named hand-step stop that
  fires when the test PASSES with a guard-only assertion set) — untouched.
- One PR per feature (no drive-by refactors).
