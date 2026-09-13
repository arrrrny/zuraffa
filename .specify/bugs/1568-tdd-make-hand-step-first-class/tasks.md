# Tasks: `tdd make` — first-class hand-step run state (issue #1568)

- **Slug**: 1568-tdd-make-hand-step-first-class
- **Ordering**: MVP-first — the make classification (SC-1/SC-2) before the
  driver propagation (SC-3..SC-6); every behavior task carries its test task
  FIRST ([behavior: <id>] markers per the TDD extension).

## Phase A — make classification (behaviors A-1568-*)

- [ ] T001 [behavior: A-1568-m1] Test: `MakeOutcome.handStep` exists with
  label `hand-step` and is NOT in the make green family (model test).
- [ ] T002 [behavior: A-1568-m2] Test: the make classifier
  (`MakeHandStepClassifier` / command-side helper) returns TRUE for a
  declared entity-shaped contract return (`ScanSession`, `List<Task>`),
  FALSE for scalars/void/nullable scalars/undeclared.
- [ ] T003 (non-behavioral) Implement: `MakeOutcome.handStep('hand-step')` in
  `generation_plan.dart`; the classifier helper in `make_command.dart`.
- [ ] T004 [behavior: A-1568-s1] Test (command-level): a make whose plan
  completed but whose target test is still red, with an entity-shaped
  declared contract return, prints
  `make: behavior=<id> outcome=hand-step feature=<f>` and exits 1 — never
  `outcome=generation-error`.
- [ ] T005 [behavior: A-1568-s2] Test: the hand-step stop message names the
  hand step (`<id>:hand`), the declared contract, and the re-run remedy.
- [ ] T006 [behavior: A-1568-g1] GUARD test: a scalar-return behavior with a
  post-generation red keeps the honest `generation-error` stop (SC-7).
- [ ] T007 (non-behavioral) Implement the classification arm at the
  post-generation red stop (subject restore #1036 preserved, summary line
  last).

## Phase B — run-state persistence (behaviors B-1568-*)

- [ ] T008 [behavior: B-1568-r1] Test: `RunState.markHandStep` adds the id
  immutably; `toJson` emits `hand_steps`; `fromJson` reads it; a legacy
  snapshot WITHOUT the field loads with an empty set.
- [ ] T009 (non-behavioral) Implement: `RunState.handSteps` + `markHandStep` +
  JSON round-trip (`run_state.dart`).

## Phase C — driver propagation (behaviors C-1568-*)

- [ ] T010 [behavior: C-1568-d1] Test: `RunDriverCore.summaryLine` emits
  ` hand_steps=N` for a non-empty id list, nothing for empty (SC-5).
- [ ] T011 [behavior: C-1568-d2] Test (driver-level): a make child reporting
  `outcome=hand-step` parks the behavior (state stays pending), records the
  id in the persisted run state, and the run CONTINUES to the next behavior
  (SC-3/SC-6).
- [ ] T012 [behavior: C-1568-d3] Test: a KNOWN hand-step id in the loaded run
  state is NOT re-driven on resume — the driver prints the parked line and
  continues (SC-4).
- [ ] T013 [behavior: C-1568-d4] Test: the end-of-run terminal block names
  the hand-step ids with the deliberate-implementation remedy (SC-5).
- [ ] T014 (non-behavioral) Implement: the driver's `hand-step` park arm, the
  resume/phase-2 skip, `handStepIds` through `RunDriverOutcome`/`_finish`,
  the `summaryLine` token, and the end-of-run block
  (`run_driver_core.dart`).

## Phase D — closeout (non-behavioral)

- [ ] T015 `dart format .` — zero remaining formatting diffs (CI gate).
- [ ] T016 `dart analyze` on every changed file — zero new findings.
- [ ] T017 Full fast-tier sweep of the touched suites + the changed-file
  neighborhood (tdd services + commands); report ACTUAL counts.
- [ ] T018 Spec-kit artifacts committed beside the code (this file, spec.md,
  plan.md, tdd/test-list.md, tdd/verification.md).
