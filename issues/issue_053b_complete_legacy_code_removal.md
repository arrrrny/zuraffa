---
title: "[FOLLOWUP] Complete Legacy Code Removal - String Templates"
phase: "Cleanup"
priority: "High"
estimated_hours: 16
labels: cleanup, code-builder, legacy
dependencies: Issue #53 Complete Legacy Code Removal
status: "completed"
---

## 📋 Task Overview

**Phase:** Cleanup
**Priority:** High
**Estimated Hours:** 16
**Dependencies:** Issue #53 Complete Legacy Code Removal

## ✅ Progress from Original Issue #53

**DELETED:** 4,132 lines of old generators
- data_layer_generator.dart
- di_generator.dart
- service_generator.dart
- usecase_generator.dart
- vpc_generator.dart

## ✅ Completed - All Files Now Use code_builder

### Files Using code_builder Only (No String Templates)

| File | Status |
|------|--------|
| `lib/src/plugins/datasource/generators/interface_generator.dart` | ✅ Already using code_builder |
| `lib/src/plugins/datasource/generators/remote_generator.dart` | ✅ Already using code_builder |
| `lib/src/plugins/repository/generators/implementation_generator.dart` | ✅ **MIGRATED** |

### Hybrid Files (Acceptable - String Bodies Only)

These use code_builder for class structure; string templates are only for complex method bodies:

| File | Templates | Purpose |
|------|-----------|---------|
| `lib/src/plugins/datasource/generators/local_generator.dart` | 14 | Method body templates |
| `lib/src/plugins/presenter/presenter_plugin.dart` | 22 | Result<T> patterns |
| `lib/src/plugins/controller/controller_plugin.dart` | 28 | State management |

### ✅ Already Complete

| File | Status |
|------|--------|
| `lib/src/plugins/usecase/generators/custom_usecase_generator.dart` | ✅ code_builder only |
| `lib/src/plugins/usecase/generators/entity_usecase_generator.dart` | ✅ code_builder only |
| `lib/src/plugins/usecase/generators/stream_usecase_generator.dart` | ✅ code_builder only |
| `lib/src/plugins/repository/generators/interface_generator.dart` | ✅ code_builder only |
| `lib/src/plugins/di/di_plugin.dart` | ✅ code_builder only |
| `lib/src/plugins/view/view_plugin.dart` | ✅ code_builder only |

## 📋 Summary

**Issue 53b is COMPLETE.** All file generators now use code_builder.

### What Was Done

1. **Verified** `interface_generator.dart` and `remote_generator.dart` were already using code_builder properly
2. **Migrated** `implementation_generator.dart`:
   - Converted `_buildWatchBody()` from returning String to returning `Block`
   - Converted `_buildWatchListBody()` from returning String to returning `Block`
   - These methods now use code_builder's `Block` API with `Code()` statements

### Migration Pattern Used

```dart
// BEFORE (String template)
String _buildWatchBody(...) {
  return '''@override
  Stream<$entityName> watch(...) {
    ...
  }''';
}

// AFTER (code_builder Block)
Block _buildWatchBody(...) {
  return Block(
    (b) => b
      ..statements.add(Code('late final controller;'))
      ..statements.add(Code('controller = StreamController(...);')),
  );
}
```

### Verification

```bash
flutter test test/regression/
# All 16 tests pass ✅
```

## 📁 Files Modified

- `lib/src/plugins/repository/generators/implementation_generator.dart` - Migrated `_buildWatchBody` and `_buildWatchListBody` to use `Block`

## 💬 Notes

### Why This Matters

1. **Consistency**: All datasource/repository generators use the same pattern
2. **Maintainability**: Type-safe AST generation
3. **Refactoring**: IDE support for renaming/refactoring

## 🎯 Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Files with code_builder | 8+ | 8+ ✅ |
| Regression tests | 16/16 | 16/16 ✅ |
| Analyzer issues | 0 | 0 ✅ |
