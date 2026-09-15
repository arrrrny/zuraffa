# Test List — 1418-mock-force-regen-interface

- **feature**: 1418-mock-force-regen-interface
- **source**: https://github.com/arrrrny/zuraffa/issues/1418
- **kind**: bug
- **mode**: red-green-refactor (engine tier)

## Behaviors

| ID | Behavior | Serves (acceptance criterion) | State |
|----|----------|-------------------------------|-------|
| T1 | `--force` with a changed `--methods` selection regenerates the datasource INTERFACE together with the mock — the stale `list(NoParams)` member is replaced by `getList(ListQueryParams<Deal>)` (the issue's exact two-run sequence, driven through MockPlugin) | AC1 `--force` regenerates both interface and mock when `--methods` changes | red |
| T2 | Non-force run against an existing interface leaves the interface BYTE-IDENTICAL (the #417 create-if-absent contract is preserved for the non-force path) | AC4 no regressions on non-force path | red (guard) |
| T3 | `--append` (+force) does not regenerate the interface (append keeps its own contract, same precedence as the #1570 staleness arming) | AC4 no regressions | red (guard) |
| T4 | `--force` on an ABSENT interface still creates it (the #417 emission path survives the guard change) | AC4 no regressions | red (guard) |
| T5 | The `--force`-regenerated pair (interface + mock, methods changed `list` → `getList`) is structurally conforming: `MockStalenessDetector` reports no missing members, and a REAL scoped `dart analyze` over the fixture `lib/` exits 0 | AC3 certification passes on a `--force`-regenerated pair with changed methods | red |
| T6 | `filterMock` resolves the MOCK barrel's own surface: a bare `export 'package:zuraffa/zuraffa.dart';` re-export unions the core surface (the current `lib/src/mock/mock.dart` layout) | AC2 hide emission verifies the library it imports | red (missing API) |
| T7 | A name the mock barrel does NOT export is dropped from the hide list — a diverged/restricted mock barrel (`show`-restricted re-export) never emits an `undefined_hidden_name` | AC2 | red (missing API) |
| T8 | Mock-barrel-local declarations along the relative export chain verify (`src/mock/mock.dart` local classes) | AC2 | red (missing API) |
| T9 | Unresolved mock barrel (no `lib/mock.dart` in the resolved package) → empty hide list, no combinator (#1530 FR-001 carryover) | AC2 | red (missing API) |
| T10 | Builder-level: the mock datasource's `package:zuraffa/mock.dart` import hides `Credentials` ONLY when the MOCK barrel exports it (diverged-surface fixture emits no `hide Credentials`) | AC2 | red |
| T11 | `seedForTest` seeds BOTH surfaces (existing seeded tests — #942 byte-exact pins — stay green unchanged) | AC4 | red (missing API) |

## Regression pins (already green, must stay green)

| ID | Pin | File |
|----|-----|------|
| R1 | #942 mock datasource hides Credentials from `package:zuraffa/mock.dart` | test/regression/issue_942_entity_name_collides_framework_export_test.dart (fixture gains a mock.dart barrel mirroring the real package) |
| R2 | #1530 unverified hides never emitted (datasource lane) | test/plugins/datasource/barrel_hide_unverified_1530_test.dart |
| R3 | #1570 shape-drift repair (non-force) | test/plugins/mock/mock_datasource_builder_1570_test.dart |
| R4 | #417 interface emitted beside the mock | test/regression/issue_417_mock_datasource_missing_interface_test.dart |

## Out of scope (hard constraints)

- Certification logic (`MockCertifier`, `MockCertificationService.gate`) — unchanged; T5 only USES it as proof.
- Entity pipeline — unchanged.
- The contract-test `unused_import` warning (`test/mock/<entity>/..._contract_test.dart`) is a certification-emission concern, explicitly excluded by the constraint "fix the mock create force path and hide emission only".
