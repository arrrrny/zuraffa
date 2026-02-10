---
title: "[TEST] Regression Test Suite for code_builder Plugins"
phase: "Testing"
priority: "High"
estimated_hours: 16
labels: test, regression, quality, code-builder
dependencies: All plugin migrations complete
---

## 📋 Task Overview

**Phase:** Testing
**Priority:** High
**Estimated Hours:** 16
**Dependencies:** All plugin migrations complete

## ⚠️ CRITICAL: Architecture Decision

**THIS TEST SUITE MUST USE code_builder OUTPUT VERIFICATION**

The regression tests should:
- ✅ Test that code_builder-based plugins produce correct, valid Dart code
- ✅ Verify generated code compiles and follows patterns
- ✅ Test file structure, imports, and code quality
- ✅ Use `dart format` and `dart analyze` on generated output

**MUST NOT:**
- ❌ Rewrite plugins from code_builder to string templates
- ❌ Compare with legacy string-based generators (they're being removed)
- ❌ Break the ADR #002 decision for code_builder

## 📝 Description

Create a comprehensive regression test suite that verifies the new code_builder-based plugin architecture produces correct, high-quality Dart code. These tests ensure refactoring doesn't break generation quality.

The focus is on **output quality** (valid Dart, correct patterns) not comparing with legacy generators.

## ✅ Acceptance Criteria

- [ ] All plugin outputs pass `dart analyze` (no errors)
- [ ] All plugin outputs pass `dart format` check
- [ ] Generated code has correct imports and references
- [ ] Generated code follows Zuraffa patterns (Result<T>, CancelToken, etc.)
- [ ] File structure matches expected Clean Architecture layout
- [ ] Route generation produces valid GoRoute configurations
- [ ] DI registration files compile and follow get_it patterns
- [ ] Tests run in under 30 seconds each

## 📁 Files

### To Create

```
test/regression/
├── output_quality_test.dart       # Verify dart analyze/format pass
├── file_structure_test.dart        # Verify correct directory layout
├── pattern_compliance_test.dart    # Verify Result<T>, CancelToken usage
├── route_generation_test.dart      # Verify GoRoute structure
└── di_registration_test.dart       # Verify get_it patterns
```

### To Modify

None - do NOT modify any plugin source code. Tests should verify existing plugins.

## 🧪 Testing Strategy

### 1. Output Quality Tests

```dart
test('generated code passes dart analyze', () async {
  final files = await generateProductPlugin();
  for (final file in files) {
    final result = await Process.run('dart', ['analyze', file.path]);
    expect(result.exitCode, equals(0), reason: '${file.path} has errors');
  }
});

test('generated code is properly formatted', () async {
  final files = await generateProductPlugin();
  for (final file in files) {
    final result = await Process.run('dart', ['format', '--check', file.path]);
    expect(result.exitCode, equals(0), reason: '${file.path} needs formatting');
  }
});
```

### 2. Pattern Compliance Tests

```dart
test('use cases return Result<T, AppFailure>', () async {
  final content = await generateUseCase('getProduct');
  expect(content, contains('Future<Result<Product, AppFailure>>'));
  expect(content, contains('cancelToken?.throwIfCancelled()'));
});

test('controllers use ControlledWidgetBuilder', () async {
  final content = await generateController('Product');
  expect(content, contains('ControlledWidgetBuilder'));
  expect(content, contains('viewState'));
});
```

### 3. File Structure Tests

```dart
test('entity generates correct file structure', () async {
  final files = await generateEntity('Product');
  
  expect(files.map(f => basename(f.path)), equals([
    'product.dart',
    'product_repository.dart',
    'product_data_source.dart',
    'product_remote_data_source.dart',
    'product_view.dart',
    'product_presenter.dart',
    'product_controller.dart',
    'product_state.dart',
  ]));
});
```

### 4. Route Generation Tests

```dart
test('routes generate valid GoRoute configs', () async {
  final routes = await generateRoutes('Product');
  
  expect(routes, contains("/product"));
  expect(routes, contains("/product/:id"));
  expect(routes, contains("/product/create"));
  expect(routes, contains("/product/:id/edit"));
});
```

### 5. DI Registration Tests

```dart
test('DI registration follows get_it patterns', () async {
  final di = await generateDI('Product');
  
  expect(di, contains('getIt.registerLazySingleton'));
  expect(di, contains('ProductRepository'));
  expect(di, contains('ProductDataSource'));
});
```

## 💬 Notes

### What This Test Suite VERIFIES

1. **Code Quality**: Generated code is valid Dart, compiles, follows patterns
2. **Architecture**: Files go to correct directories, imports are right
3. **Patterns**: Result<T>, CancelToken, ControlledWidgetBuilder used correctly
4. **Routes**: GoRoute configurations are valid
5. **DI**: get_it registrations follow conventions

### What This Test Suite DOES NOT Do

1. ❌ Compare with legacy string-based generators (they're being removed)
2. ❌ Force plugins to use strings instead of code_builder
3. ❌ Modify plugin source code (tests should pass as-is)

### Why code_builder?

The ADR #002 decision to use code_builder provides:
- Type-safe AST generation
- Automatic formatting via dart_style
- IDE refactoring support
- Consistent output

Regression tests should verify these benefits, not work around them.

## 🎯 Success Metrics

| Metric | Target |
|--------|--------|
| Tests passing | 100% |
| Analyze errors | 0 |
| Format changes needed | 0 |
| Test execution time | < 2 minutes |
