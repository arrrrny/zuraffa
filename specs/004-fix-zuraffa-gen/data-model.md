# Data Model: Fix Zuraffa Code Generation

**Feature Branch**: `004-fix-zuraffa-gen`
**Date**: 2026-04-17

## Entities

### Import Resolution

The import resolution system transforms a target file path and a source file path into a relative import string.

**ImportPath** (conceptual, not a new class — modification to existing `CommonPatterns.entityImports`)
- Source: The file being generated (e.g., `lib/src/domain/usecases/product/get_product_usecase.dart`)
- Target: The file being imported (e.g., `lib/src/domain/entities/product/product.dart`)
- Result: Relative path from source to target (e.g., `../../entities/product/product.dart`)

### Method Name Resolution

Method names are derived from the entity name and operation type. No new data structures needed — the existing `GeneratorConfig` and switch-block mapping is sufficient.

**Current mapping** (from `entity_usecase_generator.dart:109-348`):

| Method | Class Name | Execute Expression |
|--------|-----------|-------------------|
| `get` | `Get{Entity}UseCase` | `_repository.get(params)` |
| `getList` | `Get{Entity}ListUseCase` | `_repository.getList(params)` |
| `create` | `Create{Entity}UseCase` | `_repository.create(params)` |
| `update` | `Update{Entity}UseCase` | `_repository.update(params)` |
| `delete` | `Delete{Entity}UseCase` | `_repository.delete(params)` |
| `watch` | `Watch{Entity}UseCase` | `_repository.watch(params)` |
| `watchList` | `Watch{Entity}ListUseCase` | `_repository.watchList(params)` |

### Generic Type Resolution

The `UpdateParams<IdType, DataType>` type construction is conditioned on `config.useZorphy`:

| `useZorphy` | DataType | Full Params Type |
|-------------|----------|-----------------|
| `true` | `{Entity}Patch` | `UpdateParams<{IdType}, {Entity}Patch>` |
| `false` | `Partial<{Entity}>` | `UpdateParams<{IdType}, Partial<{Entity}>>` |

**Files where this conditional must be applied consistently:**
- `entity_usecase_generator.dart` — already correct
- `interface_generator.dart` — needs fix
- `implementation_generator_simple.dart` — already correct
- `implementation_generator_cached.dart` — already correct
- `presenter_plugin.dart` — needs fix
- `remote_generator.dart` — already correct
- `local_generator_impl.dart` — already correct
- `datasource/interface_generator.dart` — already correct
- `service_interface_builder.dart` — needs fix
- `provider_builder.dart` — needs fix
- `mock_provider_builder.dart` — needs fix
- `mock_datasource_builder.dart` — already correct
- `test_builder_helpers.dart` — already correct

## Validation Rules

1. **Import paths**: Every generated import for a project-local file MUST be a valid relative path that resolves to an existing file
2. **Method names**: Every use case's execute body method call MUST match the corresponding repository interface method name
3. **Generic types**: Every `UpdateParams` construction MUST use the same `dataType` resolution (conditioned on `useZorphy`) across all layers
4. **No `package:app/`**: Zero occurrences of `package:app/` in any generated output under any configuration
