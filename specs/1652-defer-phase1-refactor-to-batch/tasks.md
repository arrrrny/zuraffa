**Template Version**: `zuraffa-1.0`

# Tasks: 1652-defer-phase1-refactor-to-batch

**Input**: Design documents from `specs/1652-defer-phase1-refactor-to-batch/` (spec.md, plan.md); test list derived deterministically by `zfa tdd plan` (5 acceptance behaviors A1–A5, one per acceptance scenario).

**Prerequisites**: plan.md, spec.md. Composes with the merged PR #1662
digest gate (untouched); the only code change is the phase-1 refactor
scheduling in `_driveBehavior`.

## 1. Behavioural (TDD red → green first) — MANDATORY, driven by the loop before T101

All behaviors drive
`test/plugins/tdd/issue_1652_defer_phase1_refactor_test.dart`
(scripted fake zfa, fast tier — `writeProfile: false`, no real suite
spawns), mirroring the bug-1588 driver-level harness shape.

- [ ] **T001** [behavior: A1] (P1) Forward-run deferral: a fresh
  2-unit feature whose makes script green drives ZERO `tdd refactor`
  spawns in phase 1; each behavior prints
  `[run] <id> refactor -> deferred (phase 2)`; every behavior lands
  DONE through the batch. Includes the #694 skip-transition variant
  (make outcome=skipped, exit 0) deferring exactly like a normal
  green. RED pre-fix (the phase-1 spawn happens).
  [FR-001, FR-002, FR-005; spec AC-1; SC-1]
- [ ] **T002** [behavior: A2] (P1) Batch-boundary scheduling: all
  gen/verify-red/make steps of ALL behaviors precede ALL refactor
  spawns, every refactor spawn carries `--pass-batch`, the run
  completes `result=complete pending=0 red=0 done=N`. RED pre-fix
  (refactor spawns interleave with makes).
  [FR-001, FR-004; spec AC-2; SC-2]
- [ ] **T003** [behavior: A3] (P1) Resume-window preservation: a
  behavior re-entering phase 1 directly at refactor (state green,
  green evidence, no make in this drive, suite fully green) still
  spawns its refactor in phase 1 exactly once, carrying
  `--pass-batch`. GREEN pre-fix (regression guard — the existing
  bug-1624 test covers the same shape; this keeps the contract inside
  the new suite too). [FR-003; spec AC-3; SC-3]
- [ ] **T004** [behavior: A4] (P2) Blocked-contract composition: a
  parked blocked contract beside a made-green unit; the unit's
  refactor defers in phase 1 and its phase-2b spawn carries
  `--exempt-behaviors contract:C1`; the run reports
  `result=blocked blocked=1` with the unit DONE. RED pre-fix (the
  deferral part). [FR-001, FR-003; spec AC-4]
- [ ] **T005** [behavior: A5] (P2) Honest stop with deferred
  refactors: a later behavior's make fails; the run stops at that
  make; the earlier behaviors stay green with their refactors deferred
  and NO phase-2b pass runs (no fabricated refactor evidence). RED
  pre-fix (earlier refactors spawned in phase 1).
  [FR-005; spec AC-5]

## 2. Non-behavioural (implement to green)

- [ ] **T101** (P1) `lib/src/plugins/tdd/commands/run_driver_core.dart` —
  add the `madeGreenThisDrive` local flag to `_driveBehavior`; set it in
  the skip/adopt arm and in the generic success path for
  `step == 'make'`; extend the deferral gate with
  `madeGreenThisDrive ||` ahead of the existing suite-global
  predicate. Nothing else changes. [plan Design §1–§2]
- [ ] **T102** (P2) Update the pinned step sequences in
  `test/plugins/tdd/two_cycle_run_commands_test.dart` to the new
  schedule (per-behavior phase-1 refactor removed; phase-2b batch
  appends the refactors in list order) — the sequences pinned exactly
  the scheduling this feature changes. Document the update in the
  cycle log. [SC-4]
- [ ] **T103** (P3) Run the SC-4 suites
  (`bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart`,
  `bug_922_refactor_preflight_baseline_test.dart`,
  `bug_1652_refactor_make_post_state_test.dart`,
  `run_driver_1652_make_post_state_test.dart`) UNMODIFIED and record
  the results; run `dart analyze` + `dart format --set-exit-if-changed`
  on the changed files. [SC-4, SC-6]
- [ ] **T104** (P2) Record the red→green evidence per behavior in
  `tdd/cycle-log.md`; run `/speckit.tdd.verify` and commit its real
  `tdd/verification.md`. [SC-5 evidence; repo contract]
