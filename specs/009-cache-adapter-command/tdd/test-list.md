# TDD Test List: 009-cache-adapter-command

**Feature**: Cache Adapter Command  
**Branch**: 009-cache-adapter-command  
**Spec**: specs/009-cache-adapter-command/spec.md  
**Plan**: (not yet created - outer-only mode)  
**Git HEAD**: 614e648  
**Date**: 2026-08-26  

---

## Test Legend

- **A** = Acceptance behavior (from spec User Story scenarios)
- **E** = Edge case (from spec Edge Cases)
- **U** = Unit behavior (from plan.md components - N/A in outer-only mode)

Status: **DONE** = existing passing test covers it | **PENDING** = needs test | **BLOCKED** = blocked by bug

---

## Acceptance Behaviors (from spec.md)

### A1: Generate adapters for entity with sub-entities
**Spec**: User Story 1, Scenario 1  
**Given** a Zuraffa project with an existing entity `Product` that has sub-entities `Category` and `Variant`  
**When** the developer runs `zfa cache adapter Product`  
**Then** Hive adapters are generated for `Product`, `Category`, and `Variant`, and all are registered in the Hive registrar.

**Status**: ✅ **DONE**  
**Test**: `test/integration/cache_adapter_test.dart` — `CreateCacheAdapterCapability > discovers sub-entities and updates hive registrar` (lines 27-194)  
**Coverage**: Verifies manual additions file contains all three entities, registrar has both extensions (`HiveRegistrar` and `IsolatedHiveRegistrar`), `AdapterSpec` entries, and `registerAdapter()` calls for all three.

---

### A2: Generate adapter for enum entity
**Spec**: User Story 1, Scenario 2  
**Given** an entity that is an enum (e.g., `ProductStatus`)  
**When** the developer runs `zfa cache adapter ProductStatus`  
**Then** a Hive adapter is generated for the enum and registered in the Hive registrar.

**Status**: ✅ **DONE**  
**Test**: `test/integration/cache_adapter_test.dart` — `CreateCacheAdapterCapability > generates adapter for enum entity` (lines 330-370)  
**Coverage**: Verifies manual additions file contains enum with correct import path, registrar has both extensions, `AdapterSpec<ProductStatus>()`, and `registerAdapter(ProductStatusAdapter())`.

---

### A3: Generate adapter for entity with no sub-entities
**Spec**: User Story 1, Scenario 3  
**Given** an entity that has no sub-entities  
**When** the developer runs `zfa cache adapter SimpleEntity`  
**Then** only one adapter is generated and registered.

**Status**: ✅ **DONE**  
**Test**: `test/integration/cache_adapter_test.dart` — `CreateCacheAdapterCapability > generates adapter for entity with no sub-entities` (lines 377-460)  
**Coverage**: Verifies only one entity entry in manual additions, registrar contains only `AdapterSpec<SimpleEntity>()` and `registerAdapter(SimpleEntityAdapter())`, no Category or Variant entries.

---

### A4: Preserve existing adapters when adding new entity
**Spec**: User Story 1, Scenario 4  
**Given** the Hive registrar file already contains adapters from previous runs  
**When** the developer runs the command for a new entity  
**Then** the existing adapters are preserved and the new ones are appended.

**Status**: ✅ **DONE**  
**Test**: `test/integration/cache_adapter_test.dart` — `CreateCacheAdapterCapability > preserves existing adapters when adding new entity` (lines 463-530)  
**Coverage**: Verifies registrar contains both `Product` and `Order` adapters after second run, manual additions has both entries.

---

### A5: No duplicate entries on re-run for same entity
**Spec**: User Story 3, Scenario 1  
**Given** adapters were already generated for `Product`  
**When** the developer runs `zfa cache adapter Product` again  
**Then** no duplicate entries are added to the registrar.

**Status**: ✅ **DONE**  
**Test**: `test/integration/cache_adapter_test.dart` — `CreateCacheAdapterCapability > handles duplicate runs without errors` (lines 209-313)  
**Coverage**: Runs capability twice, verifies `registerAdapter(ProductAdapter())` appears exactly once in each of the two extension sections.

---

### A6: Add only new sub-entity when entity updated
**Spec**: User Story 3, Scenario 2  
**Given** sub-entities of `Product` already have adapters registered  
**When** the developer adds a new sub-entity and re-runs the command  
**Then** only the new sub-entity adapter is added, existing ones remain unchanged.

**Status**: ✅ **DONE**  
**Test**: `test/integration/cache_adapter_test.dart` — `CreateCacheAdapterCapability > adds only new sub-entity when entity updated incrementally` (lines 532-610)  
**Coverage**: Verifies registrar contains all three adapters (Product, Category, Variant) with exactly one registration per extension per entity after incremental update.

---

## Edge Cases (from spec.md)

### E1: Non-existent entity - clear error with suggestions
**Spec**: Edge Case 1  
**Given** an entity name that does not exist in the project  
**When** the developer runs `zfa cache adapter NonExistent`  
**Then** the command reports a clear error and suggests available entities.

**Status**: ✅ **DONE**  
**Test**: `test/integration/cache_adapter_test.dart` — `CreateCacheAdapterCapability > returns error for non-existent entity` (lines 196-207)  
**Coverage**: Verifies `success=false` and error message contains "Entity 'NonExistent' not found".

---

### E2: Circular sub-entity references - detect and break cycle
**Spec**: Edge Case 2  
**Given** entities with circular references (A → B → A)  
**When** the command discovers sub-entities  
**Then** it detects and avoids infinite loops.

**Status**: ✅ **DONE**  
**Test**: `test/integration/cache_adapter_test.dart` — `CreateCacheAdapterCapability > handles circular sub-entity references without infinite loop` (lines 612-680)  
**Coverage**: Verifies both EntityA and EntityB registered exactly once per extension, capability completes without hanging.

---

### E3: Entity with no sub-entities
**Spec**: Edge Case 3  
**Given** an entity that has no sub-entities at all  
**When** the command runs  
**Then** only the entity's own adapter is generated.

**Status**: ✅ **DONE**  
**Note**: Same as A3 - covered by test for simple entity.

---

### E4: File system permissions - report with path and fix
**Spec**: Edge Case 4  
**Given** the registrar file cannot be written due to permissions  
**When** the command attempts to write  
**Then** the error reports the specific file path and suggested fix.

**Status**: ⏳ **PENDING**  
**Gap**: `FileUtils.writeFile` handles errors but no test forces a permission error scenario.

---

### E5: Registrar file doesn't exist - create with proper structure
**Spec**: Edge Case 5  
**Given** no `hive_registrar.dart` file exists  
**When** the command runs  
**Then** it creates the file with both extensions, `@GenerateAdapters`, part directive, and registration methods.

**Status**: ✅ **DONE**  
**Test**: `test/integration/cache_adapter_test.dart` — `CreateCacheAdapterCapability > creates registrar from scratch when it does not exist` (lines 834-913)  
**Coverage**: Verifies registrar created with both extensions, `@GenerateAdapters`, part directive, `AdapterSpec<StandaloneEntity>()`, `registerAdapter(StandaloneEntityAdapter())`, and manual additions with header.

---

## Unit Behaviors (plan.md not available - outer-only mode)

Since `plan.md` does not exist for this feature, we are in **outer-only mode** — only acceptance behaviors (A1-A6, E1-E5) are tracked. Unit behaviors will be derived if/when a plan is created.

---

## Summary

| Category | Total | DONE | PENDING | BLOCKED |
|----------|-------|------|---------|---------|
| Acceptance (A) | 6 | 6 | 0 | 0 |
| Edge (E) | 5 | 4 | 1 | 0 |
| Unit (U) | N/A | - | - | - |
| **TOTAL** | **11** | **10** | **1** | **0** |

---

## Next Steps

1. Write `tdd/verification.md` with final verdict
2. If gaps found, file bug assessments (E4 remains - file system permissions test)