**Template Version**: `zuraffa-1.0`

# Tasks: 1418-mock-force-regen-interface

## 1. Behavioural (TDD red → green first)

- [ ] **T001** (P1) `test/plugins/mock/mock_builder_1418_force_interface_test.dart`
  — force regenerates a stale interface (US1/SC-001, FR-001): seed a tree
  whose `<entity>_datasource.dart` declares `list(NoParams)`; run
  `MockBuilder.generate` with `force: true, methods: [getList]`; expect
  the interface action `overwritten`, the regenerated interface declares
  `getList(ListQueryParams<Entity>)` and no longer declares
  `list(NoParams)`. [behavior: B1-force-interface]
- [ ] **T002** (P1) same file — pair conformance after force (US1/SC-001,
  FR-003): on the same run, extract the interface member set and the mock
  implemented member set with the certification's own primitives
  (`MethodExtractor.extractMethodsFromInterface` /
  `MethodExtractor`-shape mock extraction); expect mock members ⊇
  interface members (missing set empty). [behavior: B2-pair-conformance]
- [ ] **T003** (P1) same file — non-force leaves the interface
  byte-identical (US2/SC-002, FR-002): seed the drifted tree, run with
  `force: false`; expect the interface bytes identical and the mock-side
  ledger action per #1570 (`updated` when drifted). [behavior:
  B3-nonforce-interface-untouched]
- [ ] **T004** (P1) same file — absent interface still emitted in both
  modes (US1-3/US2-2, FR-002): with no interface file, force and non-force
  runs each emit it once (`created`), mock import target exists after the
  run. [behavior: B4-absent-interface-emitted]
- [ ] **T005** (P2) same file — force honors dryRun (FR-006): force +
  dry-run leaves every file byte-identical. [behavior: B5-force-dryrun]
- [ ] **T006** (P2) same file — revert precedence preserved (FR-007):
  force + revert does not regenerate over the revert contract; revert
  behavior matches the pre-change tree. [behavior: B6-revert-precedence]
- [ ] **T007** (P2) same file — repo-derived path stability + idempotence
  (edge cases, SC-003): with `repo: DealRepository` the regenerated
  interface lands at the same path the guard computed; two consecutive
  force runs are byte-stable. [behavior: B7-idempotence]
- [ ] **T008** (P1) `test/utils/zuraffa_barrel_exports_mock_surface_test.dart`
  — mock-barrel filter semantics (US3/SC-004, FR-004/005): with a seeded
  zuraffa surface and a fixture package tree (a) diverged mock barrel (no
  bare re-export) → `filterMock` drops zuraffa-only names, `filter` keeps
  them; (b) bare re-export present → `filterMock` keeps the union;
  (c) combinator-carrying (`show`) mock re-export → only shown names
  union; (d) unresolved → both filters return empty. [behavior:
  B8-filtermock-semantics]
- [ ] **T009** (P2) `test/plugins/mock/mock_datasource_builder_hide_mock_barrel_test.dart`
  — emission-level hide verification (US3/SC-004, FR-004): the generated
  mock datasource's `package:zuraffa/mock.dart` import hides only
  mock-verified names (entity names absent from the surface never appear
  in a `hide` clause). [behavior: B9-emission-hide-verified]

## 2. Implementation (behind the tests)

- [ ] **T010** (P1) `lib/src/plugins/mock/builders/mock_builder.dart` —
  replace the create-if-absent guard (L220) with the force-aware guard
  `!exists || (config.force && !config.revert)`; keep the #417 comment
  block accurate (document the force regeneration contract). [FR-001,
  FR-002, FR-006, FR-007]
- [ ] **T011** (P1) `lib/src/utils/zuraffa_barrel_exports.dart` — add the
  mock-surface walk (local declarations along `lib/mock.dart`'s export
  chain; bare `export 'package:zuraffa/zuraffa.dart';` unions the zuraffa
  surface; combinator-carrying statements honor their combinators;
  unresolved → empty) and `filterMock`; `filter` untouched. [FR-004,
  FR-005]
- [ ] **T012** (P1) `lib/src/plugins/mock/builders/mock_datasource_builder.dart`
  + `lib/src/plugins/mock/builders/failing_mock_provider_builder.dart` —
  switch the two `package:zuraffa/mock.dart` hide sources from
  `EntityUtils.barrelHideNames` (zuraffa surface) to the mock-barrel
  filter. [FR-004]

## 3. Regression & polish (non-behavioral)

- [ ] **T013** (P1) Run the pinned regression set and record results:
  `test/plugins/mock/` (incl. `mock_datasource_builder_1570_test.dart`
  U4 precedence, `mock_builder_test.dart`, capability + certify-gate
  suites), `test/utils/zuraffa_barrel_exports_test.dart`,
  `test/utils/framework_export_surface_test.dart`,
  `test/plugins/datasource/barrel_hide_unverified_1530_test.dart`,
  `test/regression/issue_942_entity_name_collides_framework_export_test.dart`.
  All green. [SC-005]
- [ ] **T014** (P2) `dart analyze` over the changed lib/test files — zero
  new issues; `dart pub get --no-example` then `dart format lib test` per
  AGENTS.md; verify zero formatting diffs remain. [SC-005]
- [ ] **T015** (P2) Update the in-repo docs surface the change touches
  (CHANGELOG.md Unreleased entry — user-visible `--force` interface
  regeneration + mock-barrel hide verification). No API docs reference
  the mock lane's interface guard; verify with a grep and leave the rest
  untouched.
