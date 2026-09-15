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
