# Bug Tasks: tdd-120-template-structures (issue #919)

Tests are NOT optional for this bug. Every test task must be observed RED
(failing for the right reason) before its implementation task starts.

## 1. Baseline maintenance (characterization)

- [ ] T001: Add the `**Template Version**: `zuraffa-1.0`` marker to existing
  plan-test fixtures whose specs must keep planning under the strict gate
  (bug_846 coverage-gate tests, plan_gen_contract bug-829 group,
  plan_persistence_marking_833, plan_command_ffi_835, and any other fixture the
  suite surfaces). Assertions unchanged — this is the brownfield baseline
  update the intended behavior change requires. [A2][A10]

## 2. Entity table parsing (item 1)

- [x] T002: Write RED acceptance test — a Key Entities markdown table yields
  name + fields + purpose in the plan artifact's Key entities table. [A1]
- [x] T003: Implement table-row parsing in `SpecParser.parseKeyEntities` (both
  formats; `purpose` on `SpecEntity`; table rows no longer terminate the
  section). [A1]
- [x] T004: Write RED acceptance test — a mixed table + bullets section
  extracts entities from both forms. [A11]
- [x] T005: Make T004 green (may fall out of T003; prove it). [A11]
- [x] T006: Write RED acceptance test — entities planned from a table are read
  back by `TestListReader.readEntities` (phase-0 seam). [A3]
- [x] T007: Make T006 green (artifact format feeds the existing reader; adjust
  rendering only if the seam fails). [A3]

## 3. Template Version gate (item 4, strict)

- [x] T008: Write RED acceptance tests — missing marker → exit 3 + `--> fix:`
  line + no artifacts; unknown version → exit 3 naming it; `zuraffa-1.0` →
  plan proceeds exit 0. [A4][A5][A6]
- [x] T009: Implement `parseTemplateVersion` + the strict gate in
  `zfa tdd plan`, running before the coverage gate and before any artifact
  write. [A4][A5][A6]
- [x] T010: Write RED acceptance test — a spec with both drift and a coverage
  gap exits 3 (gate ordering). [A13]
- [x] T011: Make T010 green (ordering proof; may fall out of T009). [A13]

## 4. Dependencies & Layer Contracts (items 2-3, plan side)

- [x] T012: Write RED acceptance test — External Dependencies & Contracts
  table lands row-for-row in the plan artifact. [A7]
- [x] T013: Implement `SpecDependency` parsing + artifact rendering
  (`## External dependencies` section). [A7]
- [x] T014: Write RED acceptance test — Layer Contracts land per-layer,
  per-interface, with signatures in the plan artifact. [A8]
- [x] T015: Implement `LayerContract` parsing + artifact rendering
  (`## Layer contracts` section). [A8]
- [x] T016: Write RED acceptance test — `TestListReader` reads dependencies
  and layer contracts back from a produced artifact. [A14]
- [x] T017: Implement `readDependencies`/`readLayerContracts` in
  `TestListReader`. [A14]

## 5. Undeclared-dependency lint (item 2 lint)

- [x] T018: Write RED acceptance tests — a requirement referencing `Hive`
  undeclared → exit 2 naming it + fix line + no artifacts; no external
  references (or declared ones) → exit 0. [A9][A12]
- [x] T019: Implement the lint in `zfa tdd plan` (known-externals set in
  `SpecParser`, declared set from the parsed table). [A9][A12]

## 6. Close-out

- [x] T020: All outer behaviors A1-A14 DONE in the test list; scoped suite
  `dart test test/plugins/tdd/` green; `dart analyze lib/src/plugins/tdd/
  test/plugins/tdd/` clean; cycle log complete; fix.md written.

## Phase 8: TDD remediation

- [ ] T021: Split A14's CLI test (bug_919_template_structures_test.dart:415)
  so the dependencies-section and layer-contract-section assertions are two
  tests, keeping the reader side in bug_919_reader_test.dart. Prove with
  `dart test test/plugins/tdd/bug_919_template_structures_test.dart` (finding 1, MED).
