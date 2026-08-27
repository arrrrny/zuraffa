# TDD Test List: Fix Polymorphic Mock Data Generation

**Feature**: 006-fix-polymorphic-mock-data  
**Spec**: specs/006-fix-polymorphic-mock-data/spec.md  
**Plan**: specs/006-fix-polymorphic-mock-data/plan.md  
**TDD Profile**: .specify/memory/tdd-profile.md  
**Generated At**: 2026-08-26 (commit 614e648)

---

## Behavior Inventory from Spec

| ID | User Story | Acceptance Scenario | Test Type | Status | Test Location |
|----|------------|---------------------|-----------|--------|---------------|
| A1 | US1 - Sealed Class Mock Gen | Sealed class with 2 concrete subtypes generates mock files for each | Unit | **DONE** | `test/plugins/mock/mock_builder_test.dart` - `generates mock data for sealed class concrete subtypes` |
| A2 | US1 - Sealed Class Mock Gen | Abstract intermediate subtype skipped, only leaf concrete gets mock | Unit | **DONE** | `test/plugins/mock/mock_builder_test.dart` - `skips abstract intermediate sealed subtypes and only generates leaf mocks` |
| A3 | US1 - Sealed Class Mock Gen | All abstract subtypes → warning, no mock for base | Unit | **DONE** | `test/plugins/mock/mock_builder_test.dart` - `warns and skips sealed base classes without concrete subtypes` |
| A4 | US1 - Sealed Class Mock Gen | Full CLI flow `zfa mock data SealedEntity --force` works end-to-end | Integration | **DONE** | `test/integration/polymorphic_mock_integration_test.dart` - `zfa mock data generates compilable subtype mocks for sealed hierarchies` |
| A5 | US2 - Zorphy Polymorphic | `@Zorphy(explicitSubTypes: [...])` continues to work | Unit | **DONE** | `test/plugins/mock/mock_builder_test.dart` - `generates mock data for Zorphy explicit subtypes` |
| A6 | US2 - Zorphy Polymorphic | Mixed sealed + Zorphy → deduplicated subtypes, both paths | Unit | **DONE** | `test/plugins/mock/mock_builder_test.dart` - `deduplicates mixed Zorphy and sealed subtype detection` |
| A7 | US3 - Error Messages | Missing entity file → clear error, exits fast | Unit | **DONE** | `test/plugins/mock/mock_builder_test.dart` - `throws a clear error when the entity file cannot be found` |
| A8 | US3 - Error Messages | Unresolvable nested type → warning, continues | Unit | **DONE** | `test/plugins/mock/mock_builder_test.dart` - `warns and continues when a nested entity type cannot be resolved` |

---

## Summary

- **Total Behaviors**: 8
- **DONE**: 8 (all covered by existing passing tests)
- **PENDING**: 0
- **BLOCKED**: 0

---

## Unit Test Exemplars (from TDD Profile)

- `test/core/result_test.dart` — Result matchers, basic structure
- `test/plugins/mock/mock_builder_test.dart` — Mock builder test patterns (DI via MockBuilder constructor, temp dir fixtures)
- `test/regression/issue_310_handwritten_class_test.dart` — Full codegen flow harness
- `test/integration/full_entity_workflow_test.dart` — Integration test patterns

---

## Integration Test Exemplar

- `test/integration/polymorphic_mock_integration_test.dart` — Full CLI workflow test using `RegressionWorkspace`, `runZfa`, `dart analyze`

---

## Notes

All acceptance criteria from the spec are **already implemented and tested**. The tests in `mock_builder_test.dart` (lines 437-682, 684-749) and `polymorphic_mock_integration_test.dart` cover every user story acceptance scenario. 

The TDD loop does not need to run for this feature since all behaviors are already `DONE`. The verification phase should confirm:
1. All 15 mock builder tests pass
2. The integration test passes  
3. The full test suite (`dart test test`) has no new regressions
4. Static analysis passes on modified files (`entity_analyzer.dart`, `mock_builder.dart`, `mock_entity_graph_builder.dart`, `mock_value_builder.dart`)

No new tests need to be written.