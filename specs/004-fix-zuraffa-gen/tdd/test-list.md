# TDD Test List — Feature 004-fix-zuraffa-gen

**Branch**: `004-fix-zuraffa-gen` | **Planned at**: 614e648 | **TDD Profile**: `.specify/memory/tdd-profile.md`

---

## Acceptance Behaviors (Outer Loop — from spec.md)

| ID | User Story | Acceptance Scenario | Status | Test Location |
|----|------------|---------------------|--------|---------------|
| A1 | US1 - Relative Imports | Generate Product with CRUD in zik_zak project → all imports use `../../domain/entities/...` never `package:app/` or `package:zik_zak/` | PENDING | — |
| A2 | US1 - Relative Imports | Generate in project without standard pubspec.yaml → falls back to computing relative paths from output file | PENDING | — |
| A3 | US1 - Relative Imports | Generate DI files → all domain imports use `../../domain/...` relative paths, only `package:zuraffa/zuraffa.dart` uses package import | DONE | test/regression/issue_410_di_create_usecase_di_test.dart |
| A4 | US2 - Method Names | Generate ChatSession with `--methods=get,getList,create,update,delete` → GetChatSessionUseCase `execute()` calls `_repository.get(id)` | PENDING | — |
| A5 | US2 - Method Names | Generate custom use case with `--repo=Product --method=search` → calls `_repository.search(params)` | PENDING | — |
| A6 | US2 - Method Names | Generate with `--force` on existing entity → new method names consistent, no duplicates/misspellings | PENDING | — |
| A7 | US3 - Complex Generics | Generate ChatSession with `--methods=update` → UpdateChatSessionUseCase extends `UseCase<ChatSession, UpdateParams<String, ChatSessionPatch>>` with correct syntax | DONE | test/plugins/usecase/usecase_plugin_test.dart |
| A8 | US3 - Complex Generics | Generate entity with `--methods=update` without Zorphy → params type is `UpdateParams<String, Partial<EntityName>>` with correct brackets | DONE | test/plugins/usecase/usecase_plugin_test.dart, test/plugins/repository/interface_generator_usecase_test.dart, test/plugins/presenter/presenter_usecase_test.dart |
| A9 | US3 - Complex Generics | Generate entity with non-String ID (e.g., `int`) → `UpdateParams<int, DataType>` consistent across all layers | PENDING | — |
| A10 | US4 - DI Paths | Generate full feature with `--methods=get,getList,create,update,delete --data --with=vpc --state --di` → DI file uses `../../domain/usecases/...` and `../../domain/repositories/...` | DONE | test/regression/issue_410_di_create_usecase_di_test.dart |
| A11 | US4 - DI Paths | Generate DI with `--cache` → cache imports use correct relative paths | PENDING | — |
| A12 | US4 - DI Paths | Generate DI for custom use case with `--domain=search` → use case import path resolves to domain-scoped subdirectory | PENDING | — |

---

## Unit Behaviors (Inner Loop — from plan.md)

| ID | Component | Behavior | Status | Test Location |
|----|-----------|----------|--------|---------------|
| U1 | `PackageUtils.getBaseImport` | DEPRECATED — no longer used; replaced by relative path computation in `CommonPatterns.entityImports()` | DONE (deprecated) | test/utils/package_utils_test.dart |
| U2 | `CommonPatterns.entityImports` | Computes correct relative paths based on output file location and target entity file location | DONE | test/core/builder/patterns/common_patterns_test.dart (existing) + test/regression/issue_395_generator_import_depth_test.dart |
| U3 | `EntityUseCaseGenerator` (update method) | Emits `UpdateParams<IdType, EntityPatch>` when `config.useZorphy == true` | DONE | test/plugins/usecase/entity_usecase_generator_test.dart |
| U4 | `EntityUseCaseGenerator` (update method) | Emits `UpdateParams<IdType, Partial<Entity>>` when `config.useZorphy == false` | DONE | test/plugins/usecase/entity_usecase_generator_test.dart |
| U5 | `RepositoryInterfaceGenerator` (update method) | Interface emits `UpdateParams<IdType, EntityPatch>` when `useZorphy` | DONE | test/plugins/repository/interface_generator_usecase_test.dart |
| U6 | `RepositoryInterfaceGenerator` (update method) | Interface emits `UpdateParams<IdType, Partial<Entity>>` when NOT `useZorphy` | DONE | test/plugins/repository/interface_generator_usecase_test.dart |
| U7 | `RepositoryImplementationGenerator` (update method) | Implementation emits correct UpdateParams type matching interface (simple, cached, synced) | DONE | test/plugins/repository/repository_plugin_test.dart |
| U8 | `PresenterPlugin` (update method) | Emits correct UpdateParams with useZorphy check | DONE | test/plugins/presenter/presenter_usecase_test.dart |
| U9 | `ServiceInterfaceBuilder` (update method) | Emits correct UpdateParams with useZorphy check | DONE | test/plugins/service/service_interface_builder_test.dart |
| U10 | `ProviderBuilder` (update method) | Emits correct UpdateParams with useZorphy check (lines 376, 491) | DONE | test/plugins/provider/provider_builder_test.dart |
| U11 | `MockProviderBuilder` (update method) | Emits correct UpdateParams with useZorphy check (line 740) | DONE | test/plugins/mock/mock_provider_builder_test.dart |
| U12 | `DiPlugin` | Generates DI files with relative imports from DI file location to domain layer | DONE | test/regression/issue_410_di_create_usecase_di_test.dart |
| U13 | `DiPlugin` | DI import paths resolve to actual generated usecase files | DONE | test/regression/issue_410_di_create_usecase_di_test.dart |

---

## Existing Test Coverage Summary

| Test File | Behaviors Covered |
|-----------|-------------------|
| `test/regression/issue_395_generator_import_depth_test.dart` | U2 (provider/service import depth) |
| `test/regression/issue_410_di_create_usecase_di_test.dart` | U12, U13 (DI relative imports) |
| `test/plugins/presenter/presenter_enum_id_import_test.dart` | Enum import emission for id field types |
| `test/plugins/usecase/usecase_plugin_test.dart` | Basic usecase generation (needs UpdateParams tests) |
| `test/plugins/repository/repository_plugin_test.dart` | Basic repository generation (needs UpdateParams tests) |
| `test/core/builder/patterns/common_patterns_test.dart` | Basic CommonPatterns (minimal) |

---

## Test Execution Commands

```bash
# Run single test (for inner loop)
dart test test/core/builder/patterns/common_patterns_test.dart -n "CommonPatterns builds fields and constructors"

# Run file suite
dart test test/core/builder/patterns/common_patterns_test.dart

# Run fast suite (excludes slow/regression)
dart test test

# Run regression tier
dart test --preset=regression test/regression/issue_395_generator_import_depth_test.dart

# Run integration tier
dart test --preset=integration test/integration/full_entity_workflow_test.dart
```

---

## Baseline Cycle Log Entry

```
## Baseline (2026-08-26, commit 614e648)
- Fast suite: 1552 pass, 1 fail (McpSseServer timeout - pre-existing)
- Acceptance behaviors: 0/12 DONE
- Unit behaviors: 3/13 DONE (U1 deprecated, U2 done, U12/U13 done)
- PENDING: A1-A12, U3-U11
- BLOCKED: none
```