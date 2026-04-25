# Feature Specification: Fix Zuraffa Code Generation Import and Type Emission

**Feature Branch**: `004-fix-zuraffa-gen`  
**Created**: 2026-04-17  
**Status**: Draft  
**Input**: User description: "Discoveries from an AI agent using zuraffa in project zik_zak: wrong package:app/ imports, wrong method names in use cases, garbled complex generics in UpdateChatSession use case, and DI files must use ../../domain/... relative imports."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Relative Imports Instead of Package Imports (Priority: P1)

As a developer using the ZFA CLI to generate code for my Flutter project (e.g., `zik_zak`), I want all generated imports to use relative paths instead of `package:app/...` or `package:zik_zak/...` so that the generated code compiles correctly regardless of my project's package name.

**Why this priority**: Without correct imports, generated code fails to compile entirely, blocking all other functionality. This is the most fundamental issue.

**Independent Test**: Generate any entity with CRUD methods using `zfa generate` and verify all imports in generated files use relative paths (e.g., `../../domain/entities/...`) instead of `package:app/...` or `package:<pkg>/...`.

**Acceptance Scenarios**:

1. **Given** a Flutter project with package name `zik_zak` (not `app`), **When** I run `zfa generate Product --methods=get,getList,create,update,delete --data`, **Then** all generated files use relative imports like `../../domain/entities/product/product.dart` and never contain `package:app/` or `package:zik_zak/`
2. **Given** a Flutter project without a standard pubspec.yaml location, **When** code is generated, **Then** the generator falls back to computing relative paths from the output file location rather than defaulting to `package:app/`
3. **Given** any project structure, **When** DI files are generated, **Then** all imports for project-local files use relative paths and only `package:zuraffa/zuraffa.dart` uses a package import (for the framework itself)

---

### User Story 2 - Correct Method Name Generation in Use Cases (Priority: P1)

As a developer generating use cases, I want method names in generated code to correctly match the entity name and operation type so that the generated repository calls, DI registrations, and use case implementations are consistent and compile without manual fixes.

**Why this priority**: Incorrect method names cause compilation failures across multiple generated files, requiring manual fixes that defeat the purpose of code generation.

**Independent Test**: Generate an entity with all CRUD methods and verify that every use case's `execute()` method calls the correct repository method name, and that the DI registration uses matching class and method names.

**Acceptance Scenarios**:

1. **Given** I generate a `ChatSession` entity with `--methods=get,getList,create,update,delete`, **When** I inspect `GetChatSessionUseCase`, **Then** its `execute()` calls `_repository.get(id)` with the correct parameter name and type
2. **Given** I generate a custom use case with `--repo=Product --method=search`, **When** I inspect the generated use case, **Then** it calls `_repository.search(params)` matching the configured method name
3. **Given** I generate use cases with the `--force` flag on an existing entity, **When** new methods are added, **Then** the generated method names are consistent with the naming convention and don't duplicate or misspell existing methods

---

### User Story 3 - Correct Complex Generic Type Emission (Priority: P1)

As a developer generating update use cases for entities with complex names or nested generics, I want the `UpdateParams<IdType, DataType>` type to be emitted correctly in all generated files so that the code compiles without garbled or malformed generic syntax.

**Why this priority**: Malformed generic output breaks compilation of update operations entirely, and the issue is reported to get worse with longer or more complex entity names.

**Independent Test**: Generate an entity with an update method (e.g., `ChatSession`, `UserProfile`) and verify that `UpdateParams<String, ChatSessionPatch>` (or `UpdateParams<String, Partial<ChatSession>>`) is emitted correctly in the use case, repository interface, repository implementation, presenter, and DI files.

**Acceptance Scenarios**:

1. **Given** I generate `ChatSession` with `--methods=update`, **When** I inspect `UpdateChatSessionUseCase`, **Then** the class extends `UseCase<ChatSession, UpdateParams<String, ChatSessionPatch>>` with properly formatted generic syntax
2. **Given** I generate an entity with `--methods=update` without Zorphy, **When** I inspect the update use case, **Then** the params type is `UpdateParams<String, Partial<EntityName>>` with correctly nested angle brackets and no extra whitespace or missing brackets
3. **Given** I generate an entity with a non-String ID type (e.g., `int`), **When** I inspect the update operation across all layers, **Then** `UpdateParams<int, DataType>` is consistently typed everywhere

---

### User Story 4 - Consistent DI Relative Import Paths (Priority: P2)

As a developer generating DI registration files, I want all project-local imports in DI files to use correct relative paths computed from the DI file's actual location so that imports resolve correctly without manual path adjustments.

**Why this priority**: DI files are the glue that wires everything together. Incorrect paths here break the entire dependency graph, but the issue is secondary to the core import/type issues above.

**Independent Test**: Generate a complete feature with `--data --vpcs --di` and verify that the DI registration file uses correct relative paths like `../../domain/usecases/...` and `../../domain/repositories/...` that resolve to existing files.

**Acceptance Scenarios**:

1. **Given** I generate a feature with `--methods=get,getList,create,update,delete --data --vpcs --di`, **When** I inspect the generated DI file at `lib/src/data/di/`, **Then** all domain imports use `../../domain/...` relative paths
2. **Given** I generate DI with caching enabled (`--cache`), **When** I inspect the DI file, **Then** cache-related imports also use correct relative paths to the cache policy files
3. **Given** I generate DI for a custom use case with `--domain=search`, **When** I inspect the DI file, **Then** the use case import path correctly resolves to the domain-scoped subdirectory

---

### Edge Cases

- What happens when an entity name contains numbers or special characters (e.g., `User2FA`)?
- How does the system handle generation when pubspec.yaml is in a parent directory (monorepo)?
- What happens when the output directory is outside of `lib/src/` (custom `--output`)?
- How does the system handle entities with very long names that push generic type declarations past line length limits?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The generator MUST use relative import paths for all project-local file references, never `package:<pkg>/...` style imports
- **FR-002**: The generator MUST compute relative paths dynamically based on the output file's location relative to the imported file's location
- **FR-003**: The `getPackageName()` fallback MUST NOT default to `'app'` — it must compute relative paths instead of falling back to a guessed package name
- **FR-004**: Method names in generated use cases MUST exactly match the entity name and operation type according to the naming convention (e.g., `get`, `getList`, `create`, `update`, `delete`)
- **FR-005**: Repository interface method names MUST be consistent with the method names called by generated use cases
- **FR-006**: DI registration method names and class references MUST be consistent with the generated use case and repository code
- **FR-007**: Complex generic types (e.g., `UpdateParams<IdType, DataType>`, `Partial<Entity>`) MUST be emitted with correctly formatted syntax — no missing angle brackets, no garbled output, no extra whitespace
- **FR-008**: The `UpdateParams` type MUST be consistent across all layers: use case, repository interface, repository implementation, datasource, presenter, and DI
- **FR-009**: The `useZorphy` flag MUST be consistently checked in all locations that determine whether to use `{Entity}Patch` or `Partial<{Entity}>`
- **FR-010**: DI files MUST use relative imports for domain layer references (e.g., `../../domain/...`) computed from the DI file's actual output path
- **FR-011**: Only the Zuraffa framework itself (`package:zuraffa/zuraffa.dart`) MAY use a package-style import in generated code
- **FR-012**: Generated code MUST compile successfully for any valid Flutter project package name without requiring manual import fixes

### Key Entities

- **Import Path**: Represents a reference from one generated file to another; must be computed as a relative path from source file location to target file location
- **Method Name**: Represents the operation name used across use case, repository, and DI layers; must be consistent and follow naming conventions
- **Generic Type Expression**: Represents a parameterized type like `UpdateParams<String, ChatSessionPatch>`; must be emitted with correct Dart syntax

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Generated code compiles on first run for any project with a non-`app` package name, without manual import fixes
- **SC-002**: Zero instances of `package:app/` or incorrect `package:<wrong_name>/` appear in any generated file
- **SC-003**: All generated `UpdateParams<...>` types across all layers are syntactically valid Dart and consistent with each other
- **SC-004**: Method names in use case `execute()` bodies match the corresponding repository interface method signatures in 100% of generated files
- **SC-005**: DI registration files correctly resolve all imports using relative paths, verified by successful compilation of the full generated feature stack

## Assumptions

- The `package:zuraffa/zuraffa.dart` import for the framework itself is acceptable and correct — only project-local imports need to be relative
- Relative imports will be computed from the output file location (typically under `lib/src/`) to the target file location
- The existing naming convention for methods (`get`, `getList`, `create`, `update`, `delete`, `watch`, `watchList`) is correct and only the emission/generation code needs fixing
- The Zorphy vs non-Zorphy distinction (`{Entity}Patch` vs `Partial<{Entity}>`) is the correct design; the fix is to make this consistent across all generators
- The DI file output location (`lib/src/data/di/` or similar) and its relative path to domain files (`../../domain/...`) is the intended convention
