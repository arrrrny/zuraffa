# Bug Assessment: tdd make hard-stops on planner-declared hand-step behaviors

- **Slug**: 1568-hand-step-hard-stop
- **Created**: 2026-09-13
- **Source**: https://github.com/arrrrny/zuraffa/issues/1568
- **Verdict**: valid (dogfood evidence + code trace; triage comment narrows scope to the run level)
- **Severity**: high (a feature with hand-steps can never drive its mechanical behaviors in one pass)

## Report

The planner pre-declares hand-steps (`Seam cost: 10 of 14 unit behaviors
will hand-step because return is an entity.` — SPEC 1489 forecast), but
the run driver treats the same condition as a fatal `generation-error`:
`make` fails with `target test still fails after generation`, the run
stops at `stopped_at=U1:make`, and every mechanical behavior behind the
first hand-step is unreachable. Resume re-drives into the same wall.

Triage comment narrows the scope: make-level hand machinery exists
(`handStepHeader` attestation + `--born-green`); what is missing is the
RUN-level state — the loop must continue past hand-steps and the count
must be named in the final summary.

## Symptom

`make` failure on an entity-return contract subject is graded
`generation-error` and stops the run, contradicting the planner's own
pre-declared forecast.

## Reproduction

1. Feature whose spec declares a contract returning an entity with no
   registry entry (e.g. `ScanService: scan() -> ScanSession`).
2. `zfa tdd run <feature>` with a scripted make that reports the real
   shape: `outcome=generation-error` + `target test still fails after
   generation`.
3. Observe: run stops at the first seam behavior; mechanical behaviors
   behind it are never driven.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/run_driver_core.dart` — the
  `!result.success` arm chain in `_driveBehavior`: no arm matches
  `outcome == 'generation-error'` on a seam behavior, so the honest-stop
  fall-through fires (`stopped_at=<id>:make`, loop terminates).
- `_entityReturnSeamForecast` — the SPEC 1489 forecast is computed
  OUTPUT-ONLY inside the `announce` guard (a count, ids discarded).
- `lib/src/plugins/tdd/services/unit_contract_shape.dart` —
  `countEntityReturnSeamsResolved` (count-only API).
- `lib/src/plugins/tdd/commands/make_command.dart` — the
  `target test still fails after generation` stop prints
  `outcome=generation-error` (the honest-red marker the driver can key
  on).

## Root Cause Hypothesis

The planner's hand-step verdict exists only as an announce string; the
driver's failure classifier never consults it. The designed non-green
state therefore falls into the generic generation-error stop.

## Proposed Remediation

Run-level only (the triage scope):

1. `UnitContractShape.entityReturnSeamIndicesResolved` — per-behavior
   seam verdict (the count API kept for compat); the driver's forecast
   helper becomes `_entityReturnSeamIds` and is computed ONCE before the
   announce (the announce uses its length).
2. New driver arm before the honest stop: `make` +
   `outcome=generation-error` + behavior in the forecast + make's
   transcript carries `still fails after generation` → park: state
   keeps its honest red, the reason is recorded in a `handSteps` map,
   the loop continues (the #1544 pattern). Phase-2a skips hand-stepped
   rows (the make already burned); phase-2b never touches non-green.
3. End of pass: a terminal branch names the hand-steps
   (`hand-step for <ids>`), stops with `stopped_at=<first>:hand` (the
   #1308 named-hand-step shape, which already feeds the journal
   violation), prints resume guidance (`--born-green`), and the summary
   line gains `hand_steps=N`. Journal violations carry
   `parked-hand-step=<id> (<reason>)` like the #992 widget skips (its
   own token — `hand-step=<id>:hand — …` stays the #1308/#1323/#1373/
   #1411 remedy grammar).
4. Two-signal gate (FR-001 discipline): a REAL generation failure on a
   seam behavior (marker absent) and the marker on a NON-seam behavior
   both keep the honest generic stop.

## Risks & Considerations

- The stop shape reuses `result=stopped` (machine contract unchanged);
  the new `hand_steps=N` summary token is additive.
- The forecast must never crash the run: resolution failures give an
  empty set (fail-open to the generic stop — the pre-fix behavior).

## Open Questions

- None; the triage comment fixes the scope.
