# Quickstart: Fixing Zuraffa Code Generation

**Feature Branch**: `004-fix-zuraffa-gen`
**Date**: 2026-04-17

## Problem

When using Zuraffa to generate code for a Flutter project with a non-`app` package name (e.g., `zik_zak`), generated files contain broken imports like `package:app/src/domain/entities/...` instead of working relative imports. Additionally, `UpdateParams` generic types are inconsistent across layers when `useZorphy` is disabled.

## Solution Overview

Three fixes applied to the Zuraffa code generation pipeline:

### Fix 1: Relative Import Paths

**What**: Replace `PackageUtils.getBaseImport()` (which produces `package:{name}/...` strings) with relative path computation in `CommonPatterns.entityImports()`.

**Where**: 
- `lib/src/core/builder/patterns/common_patterns.dart` — `entityImports()` method
- `lib/src/utils/package_utils.dart` — may be deprecated

**How**: Instead of `$baseImport/domain/entities/...`, compute the relative path from the output file to the target entity file. Use `path.relative()` (already proven in `test_builder_entity.dart`).

### Fix 2: Consistent `useZorphy` Check for Update Operations

**What**: Add `config.useZorphy` conditional to 6 generators that currently always use `{Entity}Patch`.

**Files to modify**:
1. `lib/src/plugins/repository/generators/interface_generator.dart:342`
2. `lib/src/plugins/presenter/presenter_plugin.dart:610`
3. `lib/src/plugins/service/builders/service_interface_builder.dart:165`
4. `lib/src/plugins/provider/builders/provider_builder.dart:376,491`
5. `lib/src/plugins/mock/builders/mock_provider_builder.dart:740`

**Pattern** (match `entity_usecase_generator.dart:195-197`):
```dart
final dataType = config.useZorphy
    ? '${entityName}Patch'
    : 'Partial<$entityName>';
```

### Fix 3: Method Name Verification

**What**: Add integration tests for method name consistency across generators.

**How**: Generate code for entities with various naming patterns and verify cross-layer consistency.

## Verification

After implementation, verify by:

1. Generate a complete feature for a project named `zik_zak`:
   ```bash
   zfa generate ChatSession --methods=get,getList,create,update,delete --data --vpcs --state --di
   ```

2. Check all generated files contain zero `package:app/` or `package:zik_zak/` imports

3. Check `UpdateParams` types are consistent across all layers when `--zorphy` is NOT used

4. Run existing test suite:
   ```bash
   dart test
   ```
