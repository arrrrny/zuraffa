---
feature: 1418-mock-force-regen-interface
loop: outside-in
profile: .specify/memory/tdd-profile.md
---

# Cycle Log: 1418-mock-force-regen-interface

Real red-green-refactor evidence. Every command below was actually run on
branch `feat/1418-mock-force-regen-interface` with Dart 3.13.4 stable;
pre-test kernel-cache cleanup (`rm -rf .dart_tool/test/`,
`rm -f $TMPDIR/dart_test.kernel.*`) ran before every suite.

## Round 1 — A1..A4 (force interface regeneration)

### RED (before any lib/ change)

```
dart test test/plugins/mock/mock_builder_1418_force_interface_test.dart
00:00 +6 -4: Some tests failed.

Failing tests:
  A1 — force regenerates the stale interface … interface is rewritten from the current --methods   [E]
  A2 — the force-regenerated pair conforms … interface members ⊆ mock members (certification oracle) [E]
  U1 — force honors dryRun … no bytes change; ledger carries the would-be regeneration               [E]
  U3 — repo-derived path stability repo config regenerates the SAME interface path, no second file   [E]
```

Right-reason check: every failure is `Expected: not null / Actual: <null>`
on the interface's ledger entry — the create-if-absent guard
(`mock_builder.dart` L220) never invoked the interface writer, so the
stale interface survived the force run. Exactly the #1418 defect. The four
passing tests (A3 non-force byte-identical, A4 absent-interface emitted,
U2 revert precedence, U4 idempotence) pin the contracts that must survive
the fix — passing pre-fix is expected for those.

```
dart test test/utils/zuraffa_barrel_exports_mock_surface_test.dart \
          test/plugins/mock/mock_datasource_builder_hide_mock_barrel_test.dart
00:00 +1 -2: Some tests failed.

Failing tests:
  test/utils/zuraffa_barrel_exports_mock_surface_test.dart: loading …   [E]   (compile red: filterMock does not exist)
  test/plugins/mock/…hide_mock_barrel_test.dart: diverged mock barrel … [E]   (the emitted mock.dart import HIDES Credentials — the asymmetry, live)
```

### GREEN (after T010/T011/T012)

- `mock_builder.dart`: guard → `!exists || (config.force && !config.revert)`.
- `zuraffa_barrel_exports.dart`: mock-surface walk (`_collectMockSurface`)
  + `filterMock`; `filter` untouched; parse helpers hoisted to statics
  (refactor, no behavior change — full 1530 suite re-run green).
- `entity_utils.dart`: `mockBarrelHideNames` (filterMock-backed).
- `mock_datasource_builder.dart` + `failing_mock_provider_builder.dart`:
  mock-barrel hide source switched.

```
dart test test/plugins/mock/mock_builder_1418_force_interface_test.dart \
          test/utils/zuraffa_barrel_exports_mock_surface_test.dart \
          test/plugins/mock/mock_datasource_builder_hide_mock_barrel_test.dart
00:01 +20: All tests passed!
```

## Round 2 — regression sweep (SC-005)

First sweep found ONE red:

```
dart test test/plugins/mock/ test/utils/zuraffa_barrel_exports_test.dart \
          test/utils/framework_export_surface_test.dart \
          test/plugins/datasource/barrel_hide_unverified_1530_test.dart \
          test/regression/issue_942_entity_name_collides_framework_export_test.dart
00:01 +237 -1: Some tests failed.
Failing: issue_942…: mock datasource hides Credentials from package:zuraffa/mock.dart
```

Diagnosis: NOT a production regression — the #942 fixture package shipped
`lib/zuraffa.dart` but NO `lib/mock.dart`, so under the new (correct)
verification target the mock-barrel surface was empty. The test's
assertion (`import 'package:zuraffa/mock.dart' hide Credentials,
CredentialsPatch;`) is the #942 contract and stays untouched; the FIXTURE
was brought in line with the real package layout (mock.dart bare-re-exporting
zuraffa.dart), which is what the union semantics protect.

```
dart test test/regression/issue_942_entity_name_collides_framework_export_test.dart
00:01 +6: All tests passed!
```

Full sweep after the fixture correction:

```
dart test test/plugins/mock/ test/utils/zuraffa_barrel_exports_test.dart \
          test/utils/framework_export_surface_test.dart \
          test/plugins/datasource/barrel_hide_unverified_1530_test.dart \
          test/regression/issue_942_entity_name_collides_framework_export_test.dart
01:30 +238: All tests passed!
```

Covered: the #1570 suite incl. U4 precedence (revert / append / force),
mock_builder_test, capability + certify-gate suites, #1530 hide suites
(unverified → no combinator), #942 collision suite, framework export
surface suite.

## Refactor pass

- Hoisted the export-statement parse helpers (`_exportStatements`,
  `_combinatorNames`, `_declaredType`) to statics so the zuraffa walk and
  the new mock walk share ONE parser (no duplicated combinator grammar).
- `filter` verified unchanged (its own suite + the 1530/942 suites green).
- Suite re-run after refactor: **238/238 green** (same command as above).

## Mutation evidence

See `tdd/verification.md` — the mutation matrix over the changed guard and
the two filter surfaces, each killed by the listed behavior.
