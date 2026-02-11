---
title: "[FOLLOWUP] Complete Legacy Code Removal - String Templates"
phase: "Cleanup"
priority: "High"
estimated_hours: 24
labels: cleanup, code-builder, legacy
dependencies: Issue #53 Complete Legacy Code Removal
status: "pending"
---

## 📋 Task Overview

**Phase:** Cleanup
**Priority:** High
**Estimated Hours:** 24
**Dependencies:** Issue #53 Complete Legacy Code Removal

## ⚠️ Problem Statement

PR #53 claimed to remove legacy string-based generators but **FAILED to complete the task**. The following files still use string templates instead of code_builder:

### Files Still Using String Templates (OLD CODE)

| File | String Templates | Issue |
|------|-----------------|-------|
| `lib/src/generator/graphql_generator.dart` | 12 | Most problematic - entire GraphQL generation uses strings |
| `lib/src/generator/repository/generators/implementation_generator.dart` | 14 | Repository implementation uses strings |
| `lib/src/generator/route_generator.dart` | 4 | Route generation uses strings for GoRoute |
| `lib/src/generator/provider_generator.dart` | 1 | Single string template for provider |
| `lib/src/generator/test_generator.dart` | 2 | Test templates use strings |
| `lib/src/plugins/view/view_plugin.dart` | 2 | View generation uses strings |

### Files Missing code_builder Entirely

| File | Status |
|------|--------|
| `lib/src/generator/cache_generator.dart` | Uses FileUtils but no code_builder |
| `lib/src/generator/code_generator.dart` | Orchestrator only - OK |
| `lib/src/generator/method_appender.dart` | Uses AST but no code_builder |
| `lib/src/generator/mock_generator.dart` | Uses FileUtils but no code_builder |
| `lib/src/generator/observer_generator.dart` | Uses FileUtils but no code_builder |
| `lib/src/generator/state_generator.dart` | Uses strings - should use code_builder |
| `lib/src/plugins/repository/generators/entity_usecase_generator.dart` | Missing code_builder |
| `lib/src/plugins/datasource/datasource_plugin.dart` | Missing code_builder |
| `lib/src/plugins/repository/repository_plugin.dart` | Missing code_builder |
| `lib/src/plugins/service/service_plugin.dart` | Missing code_builder |
| `lib/src/plugins/usecase/usecase_plugin.dart` | Orchestrator only - OK |

## 📝 Description

Complete the migration from string-based code generation to code_builder. This is a follow-up to issue #53 which failed to fully complete the migration.

All code generation should use:
- `SpecLibrary.emitLibrary()` for library generation
- `code_builder` Class, Method, Field, Constructor specs
- `DartFormatter` for consistent formatting

## ✅ Acceptance Criteria

### Phase 1: Migrate String Template Files

- [ ] `graphql_generator.dart` - Migrate all 12 string templates to code_builder
- [ ] `repository/generators/implementation_generator.dart` - Migrate all 14 string templates to code_builder
- [ ] `route_generator.dart` - Migrate GoRoute generation to code_builder
- [ ] `provider_generator.dart` - Migrate single string template to code_builder
- [ ] `test_generator.dart` - Migrate test templates to code_builder
- [ ] `view_plugin.dart` - Migrate View generation to code_builder

### Phase 2: Add code_builder to Missing Files

- [ ] `cache_generator.dart` - Use code_builder for cache key/manager classes
- [ ] `method_appender.dart` - Use code_builder for method templates
- [ ] `mock_generator.dart` - Use code_builder for mock classes
- [ ] `observer_generator.dart` - Use code_builder for observer classes
- [ ] `state_generator.dart` - **Already has code_builder imports** - verify usage
- [ ] `repository/generators/entity_usecase_generator.dart` - Use code_builder
- [ ] `datasource/datasource_plugin.dart` - Use code_builder
- [ ] `repository/repository_plugin.dart` - Use code_builder
- [ ] `service/service_plugin.dart` - Use code_builder

### Phase 3: Verification

- [ ] All tests pass (flutter test)
- [ ] No analyzer issues (flutter analyze)
- [ ] Generated code is properly formatted
- [ ] Code quality checks pass

## 📁 Files to Modify

### High Priority (String Templates)

```
lib/src/generator/graphql_generator.dart        ⚠️ 12 string templates
lib/src/generator/repository/generators/implementation_generator.dart ⚠️ 14 string templates
lib/src/generator/route_generator.dart           ⚠️ 4 string templates
lib/src/generator/provider_generator.dart        ⚠️ 1 string template
lib/src/generator/test_generator.dart          ⚠️ 2 string templates
lib/src/plugins/view/view_plugin.dart          ⚠️ 2 string templates
```

### Medium Priority (Missing code_builder)

```
lib/src/generator/cache_generator.dart
lib/src/generator/method_appender.dart
lib/src/generator/mock_generator.dart
lib/src/generator/observer_generator.dart
lib/src/generator/state_generator.dart
lib/src/plugins/repository/generators/entity_usecase_generator.dart
lib/src/plugins/datasource/datasource_plugin.dart
lib/src/plugins/repository/repository_plugin.dart
lib/src/plugins/service/service_plugin.dart
```

### Reference Files (Already Using code_builder Correctly)

```
lib/src/plugins/datasource/generators/local_generator.dart       ✅ Example
lib/src/plugins/datasource/generators/interface_generator.dart   ✅ Example
lib/src/plugins/usecase/generators/custom_usecase_generator.dart ✅ Example
lib/src/plugins/controller/controller_plugin.dart                ✅ Example
lib/src/core/builder/shared/spec_library.dart                   ✅ Reference
lib/src/core/builder/patterns/common_patterns.dart               ✅ Reference
```

## 🔍 Detailed Analysis

### graphql_generator.dart Issues

**Current (WRONG):**
```dart
return '''
const String get${config.name}Query = '''
query Get${config.name} {
  ${config.name}(${paramString}) {
${fieldString}
  }
}
''';
```

**Expected (code_builder):**
```dart
final queryConstant = Class(
  (b) => b
    ..name = 'Get${config.name}Query'
    ..fields.add(
      Field(
        (f) => f
          ..name = 'query'
          ..type = refer('String')
          ..modifier = FieldModifier.constant_
          ..assignment = Code('"""query Get${config.name} { ... }"""'),
      ),
    ),
);

return specLibrary.emitLibrary(
  specLibrary.library(specs: [queryConstant]),
);
```

### implementation_generator.dart Issues

**Current (WRONG):**
```dart
return '''@override
Future<void> create(${config.name} ${entityCamel}) async {
  logger.info('Creating ${dataSourceName}');
  final result = await _remoteDataSource.create(${paramString});
  logger.info('${dataSourceName} created successfully');
  return result;
}''';
```

**Expected (code_builder):**
```dart
final method = Method(
  (m) => m
    ..name = 'create'
    ..returns = refer('Future<void>')
    ..requiredParameters.add(
      Parameter(
        (p) => p
          ..name = entityCamel
          ..type = refer(config.name),
      ),
    )
    ..modifier = MethodModifier.async
    ..body = Block.of([
      Code('logger.info(\'Creating $dataSourceName\');'),
      Code('final result = await _remoteDataSource.create($paramString);'),
      Code('logger.info(\'$dataSourceName created successfully\');'),
      Code('return result;'),
    ]),
);

return specLibrary.emitLibrary(
  specLibrary.library(specs: [clazz]),
);
```

## 🧪 Testing Requirements

Run before and after migration:

```bash
# All tests should pass
flutter test

# No analyzer issues
flutter analyze lib/src/generator/
flutter analyze lib/src/plugins/

# Generated code quality
flutter test test/regression/output_quality_test.dart
flutter test test/regression/pattern_compliance_test.dart
```

## 💬 Notes

### Why code_builder Matters

1. **Type Safety**: AST checked at generation time, not runtime
2. **Refactoring**: IDE support for renaming/refactoring
3. **Consistency**: Automatic formatting via dart_style
4. **Maintainability**: Structured code, not magic strings

### Migration Pattern

For each file:

1. Identify string templates (lines with `return '''`)
2. Replace with equivalent code_builder Spec
3. Use `SpecLibrary` for library/import management
4. Test output matches original functionality
5. Verify tests pass

### Common Patterns

**Class Generation:**
```dart
final clazz = Class(
  (b) => b
    ..name = 'ClassName'
    ..extend = refer('BaseClass')
    ..fields.addAll([...])
    ..constructors.addAll([...])
    ..methods.addAll([...]),
);
```

**Method Generation:**
```dart
final method = Method(
  (m) => m
    ..name = 'methodName'
    ..returns = refer('ReturnType')
    ..body = Code('return value;'),
);
```

**Field Generation:**
```dart
final field = Field(
  (f) => f
    ..name = 'fieldName'
    ..type = refer('FieldType')
    ..modifier = FieldModifier.final$,
);
```

## 🎯 Success Metrics

| Metric | Target |
|--------|--------|
| String templates remaining | 0 |
| Files with code_builder | 100% of generators |
| Tests passing | 100% |
| Analyzer issues | 0 |
