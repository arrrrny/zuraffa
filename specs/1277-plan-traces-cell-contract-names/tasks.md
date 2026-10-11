# Tasks: 1277-plan-traces-cell-contract-names

**Template Version**: `zuraffa-1.0`

MVP first: the smallest slice that makes the declared path reachable
end-to-end (U1 → gen → make green) ships before the reconciliation
hardening.

## 1. MVP — full trace set reaches the cells

- [ ] T001 Write the #1310 regression suite
      (`test/plugins/tdd/commands/plan_traces_cell_1310_test.dart`),
      plan-level harness per `plan_routing_provenance_test.dart`:
      repro spec (FR-001 + `traces:` + declared contract
      `TodoRepository: create(String title) -> bool`) → `zfa tdd plan`
      → assert the unit row cell reads `FR-001, TodoRepository.create`
      (RED before the fix — the cell reads `FR-001` today).
- [ ] T002 Add the `contractTraces` map in `plan_command.run()`
      (behavior.id → `frTraces[currentId]`, non-empty only) and the
      `_tracesCell` cell renderer (criterion, or criterion + names).
- [ ] T003 Wire the renderer into the legacy single-file writers
      (acceptance / widget / unit tables). Contract rows unchanged.
- [ ] T004 Wire the renderer into `_derivedLaneRows` (lane plans).
- [ ] T005 Green the T001 suite (U1 cell shape, both plan shapes).

## 2. Declared path end-to-end (gen + make)

- [ ] T006 Suite extension: plan the repro spec, `zfa tdd gen U1` →
      subject derives `bool subject_u1(String)` (declared signature),
      test asserts `expect(result, isA<bool>())`, no `vacuous-guard`
      marker; `zfa tdd make U1` on a dummy-bool subject certifies
      green (no vacuous-green refusal). RED before the fix (gen falls
      back to the guard-only pair because the cell is criterion-only).
- [ ] T007 Prove the fallback: an FR with no `traces:` continuation
      emits the criterion-only cell (byte-identical to pre-fix) in both
      plan shapes.

## 3. Reconciliation hardening (re-plan id stability)

- [ ] T008 Replace the prior-list read regex in `plan_command.run()`
      with the positional parse (leading id cell, pipe-split, traces =
      second-to-last cell, criterion = first comma-token).
- [ ] T009 Suite extension: seed a prior test list carrying the full
      trace set → re-plan preserves ids and states (SC-4); seed the
      legacy criterion-only list → ids still reconcile (compat).

## 4. Coverage completion

- [ ] T010 Lane-shape assertions for T001/T007 (04-ENGINE.md cells +
      fallback cells), closing SC-1/SC-3 on the lane path.
- [ ] T011 `dart analyze` changed files + `dart format .` clean;
      targeted suites green; update the cycle log with red/green
      evidence; write `tdd/verification.md`.

## Parallelizable

- T006 and T007 are independent of T008/T009 once T002–T004 land.
- T010 depends on T004 only.
