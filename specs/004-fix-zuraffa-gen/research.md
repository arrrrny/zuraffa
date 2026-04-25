# Research: Fix Zuraffa Code Generation Import and Type Emission

**Feature Branch**: `004-fix-zuraffa-gen`
**Date**: 2026-04-17

## R1: Import Path Generation Strategy

### Decision
Replace `PackageUtils.getBaseImport()` package-import approach with relative path computation in `CommonPatterns.entityImports()` and all callers.

### Rationale
- `PackageUtils.getPackageName()` walks up from `outputDir` looking for `pubspec.yaml` and falls back to `'app'` when not found (`package_utils.dart:36`)
- `PackageUtils.getBaseImport()` constructs `package:{name}/{subPath}` strings that propagate to all generated imports
- When the package name cannot be determined (common in AI agent contexts, monorepos, or non-standard layouts), all imports break with `package:app/...`
- The test builder (`test_builder_entity.dart`) already uses `path.relative()` to compute correct relative paths dynamically — this is the proven pattern in the codebase
- The DI plugin already uses hardcoded relative strings (`../../domain/...`) successfully
- Multiple generators (remote_generator, local_generator, view_plugin, mock builders) already use hardcoded relative paths for entities

### Current State

**Generators using `CommonPatterns.entityImports()` (package: style):**
- `entity_usecase_generator.dart` — output at `{outputDir}/domain/usecases/{domain}/` (depth 2)
- `stream_usecase_generator.dart` — output at `{outputDir}/domain/usecases/{domain}/` (depth 2)
- `presenter_plugin.dart` — output at `{outputDir}/presentation/pages/{domain}/` (depth 3, custom use cases only)
- `state_builder.dart` — output at `{outputDir}/presentation/pages/{domain}/` (depth 3, custom use cases only)
- `controller_plugin_utils.dart` — output at `{outputDir}/presentation/pages/{domain}/` (depth 3)
- `interface_generator.dart` — output at `{outputDir}/domain/repositories/` (depth 2)
- `implementation_generator_append.dart` — output at `{outputDir}/data/repositories/` (depth 2)

**Generators already using relative paths:**
- `remote_generator.dart` — `../../../domain/entities/...`
- `local_generator.dart` — `../../../domain/entities/...`
- `view_plugin.dart` — `../../../domain/entities/...`
- `mock_datasource_builder.dart` — `../../../domain/entities/...`
- `mock_provider_builder.dart` — `../../../domain/entities/...`
- `di_plugin.dart` — `../../domain/...` (all DI registration files)

### Approach
Modify `CommonPatterns.entityImports()` to compute relative paths from the output file location to the target entity file location, instead of using `PackageUtils.getBaseImport()`. This requires passing the output file path (not just the output directory) so relative depth can be calculated.

### Alternatives Considered
1. **Fix `getPackageName()` to always find the right name** — Rejected: fragile, doesn't help in monorepos or non-standard layouts
2. **Keep package imports but default to a better fallback** — Rejected: still breaks for any non-standard package name
3. **Use `path.relative()` everywhere** — Viable but requires refactoring all generators; `CommonPatterns.entityImports()` is the central point to fix

---

## R2: Complex Generic Type Emission Consistency

### Decision
Unify `useZorphy` checking across all update-method generators: interface_generator, presenter_plugin, service_interface_builder, provider_builder, and mock_provider_builder.

### Rationale
- `entity_usecase_generator.dart:195` correctly checks `config.useZorphy` and produces either `${entityName}Patch` or `Partial<$entityName>`
- `interface_generator.dart:342` always uses `'${config.name}Patch'` — **never checks `useZorphy`**
- `presenter_plugin.dart:610` always uses `'${entityName}Patch'` — **never checks `useZorphy`**
- `service_interface_builder.dart:165` always uses Patch
- `provider_builder.dart:376,491` always uses Patch
- `mock_provider_builder.dart:740` always uses Patch
- When `useZorphy=false`, this causes a type mismatch: the use case expects `UpdateParams<Id, Partial<Entity>>` but the repository interface defines `update(UpdateParams<Id, EntityPatch> params)` — compilation fails

### Approach
Add `config.useZorphy` conditional to all generators that construct `UpdateParams` types, matching the pattern in `entity_usecase_generator.dart:195-197`:
```dart
final dataType = config.useZorphy
    ? '${entityName}Patch'
    : 'Partial<$entityName>';
```

### Files to Update
| File | Line(s) | Current Behavior | Fix |
|------|---------|-----------------|-----|
| `interface_generator.dart` | 342 | Always `Patch` | Add `useZorphy` check |
| `implementation_generator_simple.dart` | 83-88 | Already checks | Verify consistency |
| `presenter_plugin.dart` | 610 | Always `Patch` | Add `useZorphy` check |
| `service_interface_builder.dart` | 165 | Always `Patch` | Add `useZorphy` check |
| `provider_builder.dart` | 376, 491 | Always `Patch` | Add `useZorphy` check |
| `mock_provider_builder.dart` | 740 | Always `Patch` | Add `useZorphy` check |
| `mock_datasource_builder.dart` | 517 | Already conditional | Verify consistency |
| `remote_generator.dart` | 250 | Already conditional | Verify consistency |
| `local_generator_impl.dart` | 166, 183, 355 | Already conditional | Verify consistency |
| `datasource/interface_generator.dart` | 182 | Already conditional | Verify consistency |
| `test_builder_helpers.dart` | 93, 191 | Already conditional | Verify consistency |

### Alternatives Considered
1. **Extract a shared helper for dataType resolution** — Viable but adds indirection; inline conditional is simpler and matches existing code style
2. **Always use Patch** — Breaking change for users who don't use Zorphy

---

## R3: Method Name Generation Audit

### Decision
Audit method name generation across all generators to identify and fix any inconsistencies.

### Rationale
- The `entity_usecase_generator.dart:109-348` switch block maps methods to class names and execute expressions consistently
- The `di_plugin.dart:1062-1098` `_getUseCaseInfo()` mirrors the naming
- Custom use case method names come from `generator_config.dart:358-374` (`getRepoMethodName()`, `getServiceMethodName()`)
- The user reports "wrong method names" but specific cases are not documented
- Most likely cause: method name mismatch when entity names have complex casing (e.g., `ChatSession` → should be `chatSession` in camelCase, `chat_session` in snake_case)

### Approach
1. Add integration tests that generate code for entities with various name patterns (simple `Product`, compound `ChatSession`, acronym-heavy `User2FA`, single-char `A`)
2. Verify method name consistency between use case `execute()` body, repository interface method, and DI registration

### Alternatives Considered
1. **Wait for user to provide specific failing cases** — Viable but delays fix; proactive testing is better
2. **Rewrite method name generation** — Overkill; the existing naming logic appears sound

---

## R4: DI Import Path Computation

### Decision
DI import paths already use relative paths correctly. Verify and add tests to prevent regression.

### Rationale
- All DI plugin imports use hardcoded relative strings (`../../domain/...`, `../../data/...`)
- Only `package:zuraffa/zuraffa.dart` and `package:hive_ce_flutter/` use package style
- The `../../` depth is correct for DI files at `{outputDir}/di/{subdir}/`
- Service imports have a filesystem existence check for domain-scoped vs flat paths
- No changes needed to the DI plugin itself

### Approach
Add regression tests to verify DI import paths are correct for all DI generation modes.

### Alternatives Considered
1. **Make DI paths dynamic** — Unnecessary complexity; the fixed depth works and matches the architecture
