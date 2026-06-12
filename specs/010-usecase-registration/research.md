# Research: Existing Infrastructure for UseCase Registration

**Feature**: Declarative UseCase Registration
**Branch**: `010-usecase-registration`
**Date**: 2026-06-12

## Overview

This document consolidates findings about the existing Zuraffa infrastructure that can be reused for the UseCase Registration feature. All NEEDS CLARIFICATION markers from the spec were resolved in the specification phase (user chose CLI command approach).

---

## Decision 1: CLI Command Pattern

**Decision**: Follow the `zfa di <Name>` command pattern for all new register commands.

**Rationale**: The existing `DiPlugin.RegisterCapability` already demonstrates a clean, working pattern:
1. `DiCommand` parses CLI args and creates a `GeneratorConfig`
2. `DiPlugin` receives the config and generates the DI registration file
3. `RegisterCapability` is a `ZuraffaCapability` with `plan()` and `execute()` methods

**Alternatives Considered**:
- Mixin-based composition — rejected by user
- Dart augmentations — rejected by user  
- Annotation-based code gen — rejected by user

---

## Decision 2: Reuse AppendExecutor

**Decision**: Use the existing `AppendExecutor` with its strategies for modifying existing source files.

**Rationale**: The `AppendExecutor` already provides:
- `FieldAppendStrategy` — adds new fields to a class
- `ConstructorAppendStrategy` — adds constructor statements to a class
- `ImportAppendStrategy` — adds import directives

These strategies use the `analyzer` package to parse source files, find the right insertion points, and inject new code without breaking existing content.

**Alternatives Considered**:
- Regenerating the entire file — would destroy custom code
- String-based replacement — fragile and error-prone
- Template-based merging — more complex than needed

---

## Decision 3: Entity Name Extraction

**Decision**: Extract entity/base name from use case names by stripping known CRUD verb prefixes.

**Rationale**: Use case names follow predictable patterns:
- `GetProductUseCase`, `CreateProductUseCase` → entity = `Product`
- `ResolveInAppLinkUseCase` → no strip needed, entity = `ResolveInAppLink`

The implementation will have a known list of verb prefixes (`Get`, `Create`, `Update`, `Delete`, `Toggle`, `Watch`, `Resolve`, etc.) and strip the first match from the name, then strip the `UseCase` suffix.

**Known verb prefixes**: `Get`, `Create`, `Update`, `Delete`, `Toggle`, `Watch`, `List`, `Resolve`, `Search`, `Fetch`, `Submit`, `Validate`, `Process`, `Generate`, `Import`, `Export`, `Calculate`, `Find`, `Count`.

**Fallback**: If the user provides a `--entity` flag, use that instead of inferring.

---

## Decision 4: File Discovery by Convention

**Decision**: Locate target files by following Zuraffa v5 directory conventions.

**Rationale**: Zuraffa v5 has a fixed directory layout:
```
lib/src/presentation/pages/{domain}/
├── {entity_snake}_presenter.dart
├── {entity_snake}_controller.dart
└── {entity_snake}_state.dart
```

Domain can be inferred from the use case's location:
```
lib/src/domain/usecases/{domain}/{entity_snake}_usecase.dart
```

**Fallback**: If the file is not found at the conventional path, the user can specify `--path` or `--domain` explicitly.

---

## Decision 5: Append Content for Each Target Type

**Decision**: Each target type receives different append content.

**Presenter** — append:
1. Field: `late final {UseCaseName} _{fieldName};`
2. Constructor statement: `_{fieldName} = registerUseCase(getIt<{UseCaseName}>());`
3. Import: `import '.../{usecase}_usecase.dart';`

**Controller** — append:
1. Field: `late final {UseCaseName} _{fieldName};`
2. Constructor statement: `_{fieldName} = registerUseCase(getIt<{UseCaseName}>());`
3. Import: `import '.../{usecase}_usecase.dart';`

**State** — append:
1. Field: `final {Type} {fieldName};`
2. copyWith entry
3. Import as needed

---

## Findings Summary

| Area | Status | Details |
|------|--------|---------|
| AppendExecutor | ✅ Ready to use | FieldAppendStrategy, ConstructorAppendStrategy exist |
| DiPlugin.RegisterCapability | ✅ Reference pattern | Shows capability + command structure |
| Presenter register capability | ❌ Does not exist | Needs creation |
| Controller register capability | ❌ Does not exist | Needs creation |
| State register capability | ❌ Does not exist | Needs creation |
| Batch register command | ❌ Does not exist | Needs creation |
| Append builders for presenter/controller/state | ❌ Does not exist | Needs creation |
