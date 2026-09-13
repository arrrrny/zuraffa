**Template Version**: `zuraffa-1.0`

# Tasks: 1570-make-methods-append-propagate-mock

## 1. Behavioural (TDD red → green first)

- [ ] **T001** (P1) `test/plugins/mock/mock_datasource_builder_1570_test.dart`
  — drift repair (A1/SC-001/SC-002): build an in-memory tree with an
  interface declaring `get, getList` and a mock implementing only
  `get`; run `generateMockDataSource` with
  `appendToExisting:false, force:false`; expect action `updated`, the
  mock source contains a `getList` implementation, and the member-name
  set of the repaired mock ⊇ the interface member set. [FR-001,
  FR-002, SC-001, SC-002]
- [ ] **T002** (P1) same file — in-sync idempotence (A2/SC-003): mock
  already implements the full interface surface → action `skipped`,
  bytes untouched (repaired source identical to input). [FR-005,
  SC-003]
- [ ] **T003** (P1) same file — fail-open (A3/FR-004): interface file
  missing (and separately: interface class absent from its file) →
  action `skipped`, no exception, mock bytes untouched. [FR-004]
- [ ] **T004** (P2) same file — shape precision (U1/FR-003): missing
  set names EXACTLY the interface members absent from the mock
  (getter/helper members on the mock are not "missing"; extra mock
  members are not "invented" by the detector). [FR-003]
- [ ] **T005** (P2) same file — member-shape coverage (U2/FR-002):
  repairs for `Future<T>`, `Future<List<T>>`, `Future<void>`,
  `Stream<T>` interface members land with the body patterns the lane
  already emits (`sampleList` / `sample<T>` / `Future.value()` /
  `Stream.fromFuture`) and compile-shaped signatures
  (`name(ParamsType params) async`). [FR-002]
- [ ] **T006** (P2) same file — custom-usecase mock member preserved
  (U3): a mock carrying an extra custom-usecase method the interface
  does not declare keeps it after repair (only missing members are
  appended). [FR-002, FR-005]
- [ ] **T007** (P2) same file — revert/append/force precedence (U4):
  with `config.revert` the undo/delete path is untouched (no shape
  repair); with `appendToExisting:true` the existing append path runs
  unchanged; with `force:true` full regeneration wins (no shape
  repair needed). [FR-008, SC-005]
- [ ] **T008** (P2) same file — dry-run honesty (U5/SC-004):
  `dryRun:true` on a drifted pair → ledger reports the repair
  (`action` not `skipped`-as-clean) and the mock file bytes are
  unchanged on disk. [FR-007, SC-004]

## 2. Integration (through the make pipeline seam)

- [ ] **T009** (P2) same file or
  `test/plugins/mock/mock_create_1570_heal_test.dart` — end-to-end
  lane run through `MockPlugin.generate` (config as `mock create`
  builds it): drifted mock on disk, `generateMock:true`,
  `appendToExisting:false`, `force:false` → repaired file on disk +
  `updated` in the returned files (A1 through the real plugin entry).
  [FR-001, FR-002, FR-006, SC-001]

## 3. Non-behavioural (implementation & docs — after green)

- [ ] **T010** (P1) implement
  `lib/src/plugins/mock/services/mock_staleness_detector.dart` —
  `detectMockStaleness` per plan (fail-open guards: missing interface
  file, missing class, missing mock class, unparseable sources; drift
  = interface member names ∉ mock implemented names; reuse
  `MethodExtractor.extractMethodsFromInterface` + `AstHelper`). The
  detector is internal to the mock plugin (no barrel export). [FR-003,
  FR-004]
- [ ] **T011** (P1) wire the detector into
  `lib/src/plugins/mock/builders/mock_datasource_builder.dart` —
  arm on `fileExists && !appendToExisting && !force && !revert`; on
  drift: notice line (entity, missing members, file), append missing
  member impls via the existing append path, ledger `updated`. No
  changes to the fresh/force/revert/append-existing branches beyond
  the arming condition. [FR-001, FR-002, FR-006, FR-007, FR-008]
- [ ] **T012** (P3) document the repaired lane contract in the
  builder's doc comment (shape-check staleness vs existence skip;
  #1570 cross-reference) — no behavior. [SC-005]
