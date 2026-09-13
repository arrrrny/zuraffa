# Bug Fix: `tdd make` — first-class hand-step run state (issue #1568)

- **Slug**: 1568-tdd-make-hand-step-first-class
- **Fixed**: 2026-09-14
- **Assessment**: ./assessment.md
- **Spec**: ./spec.md
- **Red evidence**: ./red-evidence.md
- **Verification**: ./test.md
- **Status**: applied (verified — see ./test.md)
- **TDD artifacts**: `tdd/test-list.md`, `tdd/verification.md` (repo root)
- **Branch**: `feat/1568-tdd-make-hand-step-first-class`
- **Closes**: #1568

## Tooling note (spec-kit)

The repo already carries an initialized `.specify/` tree (templates, scripts,
and the `bug` + `tdd` extensions — `specify extension list` shows
`✓ TDD Extension (v1.1.2)`). Re-running `specify init` risked clobbering
exactly the files the workflow says to preserve, so the extension commands'
established artifact conventions (as exercised by the #1544 and #1486 bug
specs) were followed directly. No template or script was modified.

## Summary

The planner announces hand-step behaviors upfront (SPEC 1489 SC-4's
`Seam cost: 10 of 14 unit behaviors will hand-step because return is an
entity`), but `make` treated the SAME condition as `generation-error` and
stopped the entire run: a feature with any hand-step behavior could never
drive its mechanical behaviors, and every resume re-drove everything up to
the same wall (#1544's blocked-contract sibling).

The fix is classification + propagation only (the issue's hard constraint):
the planner, the entity pipeline (`wire` + certified mock, #1498/#1500), and
the analyze gate are untouched.

## Changes

1. **`MakeOutcome.handStep` (`outcome=hand-step`)**
   (`lib/src/plugins/tdd/models/generation_plan.dart`) — a new non-green
   outcome for the planner-declared hand step: non-fatal, exit 1, no green
   entry, the run driver parks the behavior and continues.

2. **`HandStepClassifier`** (`lib/src/plugins/tdd/services/hand_step_classifier.dart`,
   new file) — the make-side classification core. Keys on the declared
   contract's TYPE SHAPE via `UnitContractShape.isRenderableScalarType` —
   registry-INDEPENDENT, so the verdict stays stable across the phase-0
   entity creation that happens between the planner's forecast and the make.
   Resolution goes through `DeclaredRouting.declaredSignatureFor` — the SAME
   resolver the forecast uses — and fails closed to false (an undeclared or
   unreadable behavior keeps the honest generic stop).

3. **The make classification arm**
   (`lib/src/plugins/tdd/commands/make_command.dart`, the post-generation red
   stop) — when the target test is still red after generation and the
   behavior's declared contract return is entity-shaped, the make prints the
   named hand step (`<id>:hand`), the declared contract, and the re-run
   remedy, restores the subject byte-identically (#1036), and reports
   `outcome=hand-step` instead of `generation-error`. A plan that CARRIED a
   mechanical implementation surface (the entity→mock→wire pipeline) keeps
   the honest `generation-error` — a red there is a real generation outcome.

4. **`RunState.handSteps` + store round-trip**
   (`lib/src/plugins/tdd/models/run_state.dart`,
   `lib/src/plugins/tdd/services/run_state_store.dart`) — the parked
   hand-step ids persist as `hand_steps` in `tdd/run-state.json` (additive:
   a legacy snapshot loads with an empty set; a malformed value corrupts per
   the standard field contract). `markHandStep` is immutable, idempotent, and
   never moves a behavior state; `_reconcile` preserves the set (it is the
   make's classification record, not evidence-derived state).

5. **The driver park + skip + report**
   (`lib/src/plugins/tdd/commands/run_driver_core.dart`) —
   the `outcome=hand-step` arm parks the behavior (state NOT advanced past
   its honest red, the #1544 park-and-continue shape), records the id, and
   returns `stop: null` — the run CONTINUES with the remaining behaviors, so
   the mechanical behaviors behind the hand-step are reachable and drivable
   (AC-1/AC-3). Resume (phase 1) and the phase-2a re-attempt skip known
   hand-steps with a named parked line — they are never re-driven (AC-4)
   until the author implements the subject and re-runs make deliberately.
   `RunDriverCore.summaryLine` gains `hand_steps=N` (the `skipped-widget=`
   precedent) and the end-of-run terminal block names the ids with the
   deliberate-implementation remedy (AC-2) — the pass's other bounded
   terminal (FR-007), never a fake DONE (FR-008), and the pre-#1568
   internal-error branch no longer fires for parked hand-steps.

## Behavior table

| Scenario | Before | After |
| -------- | ------ | ----- |
| make: entity-return contract subject, post-generation red | `outcome=generation-error`, run wall at `<id>:make` | `outcome=hand-step`, named `<id>:hand` remedy, run continues |
| make: scalar/undeclared behavior, post-generation red | `outcome=generation-error` | unchanged (SC-7 guard) |
| make: entity-pipeline plan (wire + certified mock) red | `outcome=generation-error` | unchanged (mechanical surface exists) |
| run: first hand-step make | run stops `result=stopped stopped_at=<id>:make` | park + continue, `hand_steps=N` terminal |
| run: resume with parked hand-steps | re-drives to the same wall | parked line, never re-driven |
| run state file | — | `hand_steps` additive field |
