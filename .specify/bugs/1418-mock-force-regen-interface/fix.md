# Bug Fix: `zfa mock create --force` regenerates the whole pair; hide verified against the library it imports

- **Slug**: 1418-mock-force-regen-interface
- **Fixed**: 2026-09-16
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: specs/1418-mock-force-regen-interface/tdd/test-list.md, specs/1418-mock-force-regen-interface/tdd/verification.md (red → green → verify loop completed)

## Summary

`zfa mock create` now regenerates the WHOLE generated pair under `--force`.
Previously the datasource interface emission was create-if-absent (#417) and
was never invalidated by `--force` (nor by a `--methods` change), while the
mock body always regenerated from the current `--methods` — a changed
selection left a drifted pair (mock implements
`getList(ListQueryParams<E>)`, interface still declares `list(NoParams)`)
and `--certify` dead-ended on
`Missing concrete implementation of 'EDataSource.list'` no matter how many
times `--force` re-ran. Under `force && !append && !revert` the mock lane now
re-invokes the interface writer, whose fresh-write path overwrites the
interface from the CURRENT `config.methods` — the same contract the mock body
follows.

The secondary defect — `hide <Entity>, <Entity>Patch` emitted against
`import 'package:zuraffa/mock.dart'` while the names were verified against
the `zuraffa.dart` surface — is fixed by verifying the hide against the
library the import actually names: the mock barrel's own resolved export
surface. Correctness previously rested on `lib/src/mock/mock.dart`
bare-re-exporting the full core surface, an accident of the current layout.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/mock/builders/mock_builder.dart` | modified | The interface emission guard becomes `!exists(interfacePath) \|\| (options.force && !config.appendToExisting && !config.revert)`. Non-force keeps the #417 create-if-absent contract byte-for-byte (the writer is not invoked on an existing file, so its append path cannot fire from the mock lane); append/revert keep their own contracts (the same precedence the #1570 staleness arming applies). |
| `lib/src/utils/zuraffa_barrel_exports.dart` | modified | The seed now carries TWO resolved surfaces: `names` (`lib/zuraffa.dart`) and `mockNames` (`lib/mock.dart`'s own export chain, walked with the same #1530 combinator-aware collector; `package:zuraffa/…` re-export targets resolve back into the package). New `filterMock(hides)` verifies against `mockNames`. A missing mock barrel resolves to an EMPTY set — the hide is dropped (#1530 FR-001 carryover). `filter` is unchanged for imports of `package:zuraffa/zuraffa.dart` itself. `seedForTest` seeds both surfaces identically, so existing seeded pins (#942 byte-exact) keep their behavior. |
| `lib/src/utils/entity_utils.dart` | modified | New `EntityUtils.mockBarrelHideNames(entityName)` → `ZuraffaBarrelExports.filterMock([entity, entityPatch])` — the emission seam for files importing `package:zuraffa/mock.dart`. `barrelHideNames` stays the seam for `package:zuraffa/zuraffa.dart` imports. |
| `lib/src/plugins/mock/builders/mock_datasource_builder.dart` | modified | The mock datasource's `package:zuraffa/mock.dart` hide list (entity + Patch, plus custom-usecase return types) verifies through `mockBarrelHideNames`. |
| `lib/src/plugins/mock/builders/failing_mock_provider_builder.dart` | modified | Same seam switch for the failing provider's `package:zuraffa/mock.dart` import (#942-parity comment updated). |
| `test/plugins/mock/mock_builder_1418_force_interface_test.dart` | added (RED commit fecda600) | T1–T5: force regenerates interface+mock; non-force byte-identical; append+force keeps interface; force on absent interface creates it; structural conformance via `MockStalenessDetector`. |
| `test/plugins/mock/mock_builder_1418_force_compile_test.dart` | added (RED commit fecda600) | Engine-tier: the force-regenerated pair (methods changed `list` → `getList`) passes a REAL scoped `dart analyze` with zero errors. |
| `test/utils/zuraffa_barrel_exports_mock_surface_test.dart` | added (RED commit fecda600) | T6–T11: mock-surface resolution (re-export union, dropped names, local declarations, unresolved barrel, `seedForTest` both-surfaces) + builder-level emission (T10: no `hide Credentials` when the mock barrel does not export it). |
| `test/regression/issue_942_entity_name_collides_framework_export_test.dart` | modified | The #942 barrel fixture ships the mock barrel exactly like the real package (bare re-export of the zuraffa barrel), so the byte-exact #942 pins keep asserting the hide under the new two-surface resolution. |

## Out of scope (hard constraints honored)

- Certification logic (`MockCertifier`, `MockCertificationService.gate`) —
  UNCHANGED. The certify E2E proof runs the unmodified gate over the
  regenerated pair (see test.md).
- Entity pipeline — UNCHANGED.
- The contract-test `unused_import` warning
  (`test/mock/<entity>/…_contract_test.dart`) is a certification-emission
  concern, explicitly excluded by the constraint "fix the mock create force
  path and hide emission only".
- Suggested fix (3) from the issue — tolerating `undefined_hidden_name` in
  certification's scoped analyze — is NOT needed and NOT applied: (2)
  removes the emission at the source, so the analyzer never sees it.
