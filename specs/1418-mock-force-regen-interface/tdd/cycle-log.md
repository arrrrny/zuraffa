# Cycle Log — 1418-mock-force-regen-interface (append-only)

## Cycle 1 — RED: force-interface regeneration (T1, T5) + mock-barrel surface (T6–T11)

**Command**: `dart test test/plugins/mock/mock_builder_1418_force_interface_test.dart`

```
00:00 +3 -2: Some tests failed.
Failing tests:
  T1: --force with a changed --methods regenerates the interface together with the mock
      → Expected: interface contains 'getList(ListQueryParams<Deal>'
        Actual interface after run 2: still declares 'Future<List<Deal>> list(NoParams params);'
  T5: the --force-regenerated pair is structurally conforming
      → Expected: empty (MockStalenessDetector.detectMockStaleness)
        Actual: [Instance of 'ParsedUseCaseInfo'] — the stale list member
00:00 +3 -2  (T2, T3, T4 green — the pre-existing contracts the fix must preserve)
```

**Command**: `dart test test/utils/zuraffa_barrel_exports_mock_surface_test.dart`

```
00:00 +0 -1: Some tests failed.
  loading test/utils/zuraffa_barrel_exports_mock_surface_test.dart
  Error: Member not found: 'EntityUtils.mockBarrelHideNames' (×5 sites)
```

**Command**: `dart test test/plugins/mock/mock_builder_1418_force_compile_test.dart`

```
00:00 +0 -1: Some tests failed.
Failing tests: (setUpAll)
  → the engine-tier fixture's interface-content assertion: after
    --methods getList --force the interface still declares list(NoParams)
```

**Analysis**: RED matches the issue's live reproduction
(scripts/repro_1418.sh against the repo checkout reproduced the identical
signature: `error - Missing concrete implementation of 'DealDataSource.list'`,
`❌ mock certification for Deal failed — unsatisfied: list`). T2/T3/T4 pin the
contracts that must survive the fix (non-force create-if-absent, append,
fresh-create). The mock-surface file is red on the missing API
(`mockBarrelHideNames`/`filterMock`) plus the diverged-surface emission
behavior.

**Next**: GREEN — guard change in mock_builder.dart; mock-surface resolution
in zuraffa_barrel_exports.dart + EntityUtils.mockBarrelHideNames; mock-lane
builders switch to the mock-barrel-verified hide.

## Cycle 2 — GREEN: guard change + two-surface hide verification

**Changes**:
- `lib/src/plugins/mock/builders/mock_builder.dart`: interface emission guard
  `!exists(interfacePath) || (options.force && !config.appendToExisting && !config.revert)`.
- `lib/src/utils/zuraffa_barrel_exports.dart`: seed resolves the MOCK barrel's
  own surface (`lib/mock.dart` chain) alongside the zuraffa surface; new
  `filterMock`; unresolved barrel → empty set (#1530 FR-001 carryover);
  `seedForTest` seeds both surfaces.
- `lib/src/utils/entity_utils.dart`: `mockBarrelHideNames` emission seam.
- `lib/src/plugins/mock/builders/mock_datasource_builder.dart` +
  `failing_mock_provider_builder.dart`: mock-barrel imports verify through
  `mockBarrelHideNames`.
- `test/regression/issue_942_entity_name_collides_framework_export_test.dart`:
  #942 fixture ships the mock barrel like the real package.

**Command**: `dart test test/plugins/mock/ test/utils/zuraffa_barrel_exports_test.dart test/utils/zuraffa_barrel_exports_mock_surface_test.dart test/plugins/datasource/barrel_hide_unverified_1530_test.dart test/regression/issue_942_entity_name_collides_framework_export_test.dart test/regression/issue_417_mock_datasource_missing_interface_test.dart`

```
01:17 +229: All tests passed!
```
(interface suite 5/5, compile test 1/1, surface suite 11/11, #942 6/6,
#417 2/2, #1570 9/9, datasource lane 73/73)

**E2E** (`bash scripts/repro_1418.sh` on the fixed checkout):

```
=== STEP 2: mock create Deal --methods getList --certify --force ===
✅ mock certification: Deal conforms to DealDataSource (mock-cert:deal@cd05085d)
=== interface after step 2 (force regen?) ===
abstract class DealDataSource with Loggable, FailureHandler {
  Future<List<Deal>> getList(ListQueryParams<Deal> params);
}
```

**Mutation analogs** (both killed):
- A — guard reverted: interface suite `+3 -2` (T1, T5 fail; T2/T3/T4 green).
- B — `filterMock` → `filter` delegate: surface suite T7/T8/T10 fail.

**Analyzer / format**: scoped `dart analyze` over the changed files →
`No issues found!`; `dart format` applied, stability pass 1299 files,
0 changed.

**Next**: ship — commit GREEN, push, open PR (Closes #1418).
