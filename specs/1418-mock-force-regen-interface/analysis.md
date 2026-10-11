**Template Version**: `zuraffa-1.0`

# Analysis: 1418-mock-force-regen-interface

Cross-artifact consistency pass over `spec.md` → `plan.md` → `tasks.md`
against the codebase at branch `feat/1418-mock-force-regen-interface`
(HEAD `3ec4743e`).

## Artifact Coverage

| Requirement | Task(s) | Test behavior(s) | Status |
| -- | -- | -- | -- |
| FR-001 (force regenerates existing interface) | T010 | B1 | covered |
| FR-002 (non-force create-if-absent intact) | T010 | B3, B4 | covered |
| FR-003 (pair conforms; certification passes untouched) | T010 | B2 | covered |
| FR-004 (mock-barrel verified hide, unresolved → none) | T011, T012 | B8, B9 | covered |
| FR-005 (zuraffa surface unchanged; #942 preserved) | T011 | B8 | covered |
| FR-006 (dry-run honored) | T010 | B5 | covered |
| FR-007 (revert/append precedence) | T010 | B6 | covered |
| FR-008 (certification + entity pipeline untouched) | T013 | regression set | covered (by absence of change) |
| SC-001 | T001, T002, T010 | B1, B2 | covered |
| SC-002 | T003 | B3 | covered |
| SC-003 | T007 | B7 | covered |
| SC-004 | T008, T009 | B8, B9 | covered |
| SC-005 | T013, T014 | — (suite-level) | covered |

## Drift Checks

1. **Guard condition consistency** — spec FR-001/FR-002 and plan Change 1
   both state `!exists || (config.force && !config.revert)`; T010
   implements exactly that. The `!config.revert` conjunct mirrors the
   #1570 staleness arming (`mock_datasource_builder.dart` L79–82,
   `!options.force && !config.revert`), so the two writers' precedence
   logic stays symmetric. Consistent.
2. **`appendToExisting` reachability** — plan states the mock lane never
   sets `appendToExisting` (verified: `create_mock_capability.dart`
   L343–361 builds `GeneratorConfig` without it → default false). The
   spec's non-force byte-stability requirement therefore never routes
   through the interface builder's append branch on the mock lane.
   Consistent — and the reason the unconditional-call alternative was
   rejected in the plan.
3. **Union semantics vs #1530 FR-001** — the mock-surface union fires
   ONLY on a bare (combinator-free) `export 'package:zuraffa/zuraffa.dart';`
   inside the mock barrel's chain. A combinator-carrying statement does
   not union, so an unresolved or restricted surface can only
   under-collect (drops a hide) — never over-collect (emits an
   unverified hide). Matches #1530's under-collection-is-safe doctrine
   and the issue's fix suggestion (2). Consistent.
4. **Hard constraint boundary** — FR-008 forbids touching certification
   and the entity pipeline. T001–T009 touch only
   `test/plugins/mock/*` and `test/utils/*`; T010–T012 touch only
   `mock_builder.dart`, `zuraffa_barrel_exports.dart`, and the two
   mock-barrel emission sites. The known residual
   (`deal_mock_contract_test.dart` `unused_import`) is certification-owned
   and recorded out of scope in the spec's Assumptions. Consistent.
5. **`MethodExtractor` as the conformance oracle** — T002 uses the
   certification's own extraction primitives for the member-set proof so
   the test cannot disagree with the gate. The primitive is
   `MethodExtractor.extractMethodsFromInterface`; the mock-side
   extraction mirrors `MockCertificationService`'s implemented-member
   read (AST-only). Consistent with the #1570 precedent (FR-003 pinning
   detector = certification primitives).
6. **Ledger action expectations** — B1 expects the interface action
   `overwritten` after a force run. Traced:
   `DataSourceInterfaceBuilder.generate` fresh path →
   `FileUtils.writeFile(force: options.force)` →
   `file_utils.dart` L92–97 returns `overwritten` when the file existed.
   Consistent with the datasource plugin's existing ledger behavior.
7. **Seed surface test seam** — B8 needs BOTH a seeded zuraffa surface
   (existing `seedForTest`) and a fixture package tree on disk for the
   mock-barrel walk. `seedForTest(Set)` seeds the zuraffa surface only;
   the mock surface resolves from the real filesystem walk. The test
   fixture therefore writes a minimal fake package (`.dart_tool/
   package_config.json` + `lib/mock.dart` chain) under the temp tree and
   calls `seed(projectRoot)` — matching how
   `zuraffa_barrel_exports_test.dart` already drives resolution paths.
   No production seam change needed. Consistent.
8. **Emission-site parity** — the issue's secondary example shows the
   hide on BOTH `zuraffa.dart` and `mock.dart` imports in one generated
   file (v6.2.2 output). Current master emits the zuraffa.dart hide only
   from the interface writer (verified surface, unchanged) and the
   mock.dart hide only from the two mock-lane builders. FR-004/FR-005
   split the verification targets accordingly. Consistent — no third
   emission site hides from `mock.dart` (grep-verified:
   `mock_provider_builder.dart:119` and `test_builder_helpers.dart:466`
   import WITHOUT a combinator; the contract-test writer emits a bare
   import).

## Findings

- **F-1 (fixed in artifacts)** — the tasks list initially lacked the
  docs/polish row; T015 covers CHANGELOG + doc-grep so non-behavioral
  work lands under `/speckit.implement`.
- **F-2 (noted, no action)** — `spec.md` US3 AC-1's "diverged mock
  barrel" is a synthetic future state (today's barrel bare-re-exports);
  the test fixture synthesizes it. This is intentional: the filter's
  semantics, not today's barrel layout, are the contract.
- **F-3 (noted, no action)** — `filterMock`'s zuraffa-union needs the
  zuraffa surface resolved; when zuraffa resolution fails but the mock
  chain resolves, the union is skipped (zuraffa set empty → mock-local
  names only). Under-collection-safe; matches FR-001-of-#1530 carryover.

Verdict: **READY** — no unresolved drift.
