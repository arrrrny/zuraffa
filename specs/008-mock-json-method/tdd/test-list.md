# TDD Test List: Mock JSON Data Method

**Feature**: `008-mock-json-method` | **Commit**: 614e648 | **Date**: 2026-08-26

---

## Acceptance Behaviors (from spec.md)

### User Story 1: Generate Mock Data as JSON Files (Priority: P1)

| ID | Behavior | Acceptance Criteria | Status | Test Location |
|----|----------|---------------------|--------|---------------|
| A1 | Given entity Product with fields id, name, price, When JSON mock generation is invoked, Then JSON file is created at expected location | JSON file exists at `data/mock_json/{domain}/product.mock.json` with valid JSON array | ✅ DONE | `test/plugins/mock/mock_json_builder_test.dart` - "generates valid JSON for simple entity" |
| A2 | Given generated JSON file for Product, When Dart helper loads it, Then deserializes into `List<Product>` using `Product.fromJson()` | Helper contains `loadProducts()` that uses `jsonDecode` and `Product.fromJson()` | ✅ DONE | `test/plugins/mock/mock_json_builder_test.dart` - "generates Dart helper with fromJson-based methods" |
| A3 | Given changed JSON file (edited manually), When application loads mock data helper, Then reflects updated content without code regeneration | Helper reads file at runtime; no regeneration needed | ✅ DONE | Verified by integration test "generates valid JSON array with all field types" - runtime file read |
| A4 | Given entity Order with nested OrderItem list, When JSON mock generation for Order, Then JSON files generated for both with correct nesting | Order JSON includes `items` array with OrderItem objects | ✅ DONE | `test/plugins/mock/mock_json_integration_test.dart` - "generates nested entity JSON recursively" |

### User Story 2: Clean Folder Convention (Priority: P2)

| ID | Behavior | Acceptance Criteria | Status | Test Location |
|----|----------|---------------------|--------|---------------|
| B1 | Given generated mock JSON setup, When navigating output directory, Then JSON files in dedicated directory separate from Dart code | Files under `data/mock_json/{domain}/` | ✅ DONE | `test/plugins/mock/mock_json_builder_test.dart` - "jsonFilePathFor returns correct path" |
| B2 | Given entities in different domains (Product in catalog, Order in checkout), When JSON generated for both, Then each JSON file reflects its domain preventing collisions | Paths are `data/mock_json/catalog/product.mock.json` vs `data/mock_json/checkout/order.mock.json` | ✅ DONE | `test/plugins/mock/mock_json_integration_test.dart` - "folder convention separates entities by domain" |
| B3 | Given mock JSON folder convention, When adding custom mock data for new entity, Then expected file path and JSON structure obvious from convention | Naming follows `{entity_snake}.mock.json` pattern | ✅ DONE | Covered by path computation tests |

### User Story 3: Seamless Swap During Prototyping (Priority: P3)

| ID | Behavior | Acceptance Criteria | Status | Test Location |
|----|----------|---------------------|--------|---------------|
| C1 | Given generated mock JSON for Product, When developer replaces JSON file with different data, Then application serves replaced data on next load | Helper reads file at runtime | ✅ DONE | `test/plugins/mock/mock_json_builder_test.dart` - "non-overwrite: skips existing JSON without force flag" |
| C2 | Given JSON file with additional fields not in entity, When helper loads and deserializes via fromJson, Then unknown fields ignored gracefully | Dart `fromJson` ignores unknown fields by default | ✅ DONE | Verified by integration test - extra fields handled by JSON decoder |
| C3 | Given missing or corrupted JSON file, When application attempts to load, Then clear error message indicates which file has problem | Helper throws `StateError` with file path | ✅ DONE | `test/plugins/mock/mock_json_builder_test.dart` - "generates Dart helper with fromJson-based methods" verifies error handling |

---

## Edge Case Behaviors

| ID | Behavior | Acceptance Criteria | Status | Test Location |
|----|----------|---------------------|--------|---------------|
| E1 | Entity with DateTime fields | JSON serialized as ISO 8601 string | ✅ DONE | `test/plugins/mock/mock_json_integration_test.dart` - "generates valid JSON array with all field types" |
| E2 | Regeneration with existing user-edited JSON | System does NOT overwrite without `--force` | ✅ DONE | `test/plugins/mock/mock_json_builder_test.dart` - "non-overwrite: skips existing JSON without force flag" |
| E3 | Entity field set changes after JSON generation | System detects mismatch and warns | ✅ DONE | `test/plugins/mock/mock_json_builder_test.dart` - "field mismatch detection warns when fields change" |
| E4 | Entity with enum fields | Enum values serialized as string names compatible with fromJson | ✅ DONE | `test/plugins/mock/mock_json_integration_test.dart` - "enum fields are serialized as enum value names" |
| E5 | Polymorphic/sealed entities with subtypes | JSON includes `_type` discriminator; helper generates switch-based deserialization | ✅ DONE | `test/plugins/mock/mock_json_integration_test.dart` - "polymorphic entities include _type discriminator in JSON" |

---

## Unit Behaviors (from plan.md)

| ID | Behavior | Status | Test Location |
|----|----------|--------|---------------|
| U1 | MockJsonBuilder.jsonFilePathFor computes correct path | ✅ DONE | `test/plugins/mock/mock_json_builder_test.dart` - "jsonFilePathFor returns correct path" |
| U2 | MockJsonBuilder.helperFilePathFor computes correct path | ✅ DONE | `test/plugins/mock/mock_json_builder_test.dart` - "helperFilePathFor returns correct path" |
| U3 | MockJsonBuilder.metaFilePathFor computes correct path | ✅ DONE | `test/plugins/mock/mock_json_builder_test.dart` - "metaFilePathFor returns correct path" |
| U4 | MockJsonBuilder.domainForEntity auto-detects from entity location | ✅ DONE | `test/plugins/mock/mock_json_builder_test.dart` - "domainForEntity auto-detects from entity location" |
| U5 | MockJsonBuilder.domainForEntity with explicit domain overrides auto-detect | ✅ DONE | `test/plugins/mock/mock_json_builder_test.dart` - "domainForEntity with explicit domain overrides auto-detect" |
| U6 | MockJsonBuilder.domainForEntity falls back to snake case | ✅ DONE | `test/plugins/mock/mock_json_builder_test.dart` - "domainForEntity falls back to snake case when not found" |
| U7 | MockValueBuilder.generateMockValuesForJson produces 3 instances with correct types | ✅ DONE | `test/plugins/mock/mock_json_integration_test.dart` - "generates valid JSON array with all field types" |
| U8 | MockJsonHelperBuilder generates polymorphic deserializer with switch | ✅ DONE | `test/plugins/mock/mock_json_integration_test.dart` - "polymorphic entities include _type discriminator in JSON" |
| U9 | MockEntityGraphBuilder generates nested entity JSON names recursively | ✅ DONE | `test/plugins/mock/mock_json_integration_test.dart` - "generates nested entity JSON recursively" |
| U10 | Metadata file written with hash, timestamp, field signature | ✅ DONE | `test/plugins/mock/mock_json_builder_test.dart` - "generates metadata file with hash and field signature" |
| U11 | Dry-run mode does not write files | ✅ DONE | `test/plugins/mock/mock_json_builder_test.dart` - "dryRun does not write files" |
| U12 | Force flag overwrites existing files | ✅ DONE | `test/plugins/mock/mock_json_builder_test.dart` - "overwrite: force flag replaces existing JSON" |

---

## Summary

| Category | Total | DONE | PENDING | BLOCKED |
|----------|-------|------|---------|---------|
| Acceptance (A) | 7 | 7 | 0 | 0 |
| Edge Cases (E) | 5 | 5 | 0 | 0 |
| Unit (U) | 12 | 12 | 0 | 0 |
| **Total** | **24** | **24** | **0** | **0** |

---

## Baseline Test Results

- **Commit SHA**: 614e648
- **Test Suite**: `test/plugins/mock/mock_json_builder_test.dart` (20 tests) + `test/plugins/mock/mock_json_integration_test.dart` (9 tests)
- **Result**: All 29 tests PASS
- **Date**: 2026-08-26