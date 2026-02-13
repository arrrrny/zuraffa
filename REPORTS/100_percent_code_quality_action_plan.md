# 100% Code Quality - Action Plan

**Generated:** 2026-02-11
**Current Status:** 92%
**Goal:** 100%

---

## Current Status Dashboard

```
Documentation:  0% ████████████████████ 0/47 files
Tests:          100% ████████████████████ 11/11 builders
Architecture:   100% ████████████████████ God classes resolved
Null Safety:    100% ████████████████████ Fixed
Naming:         80% █████████████████░░░ Inconsistent
API Design:     75% █████████████████░░░ Flag args
```

---

## Priority 1: Documentation (Effort: 2 hours)

### Add class documentation to these 10 files:

```
lib/src/plugins/mock/builders/mock_builder.dart
lib/src/plugins/test/builders/test_builder.dart
lib/src/plugins/repository/generators/implementation_generator.dart
lib/src/plugins/datasource/builders/local_generator.dart
lib/src/plugins/datasource/builders/remote_generator.dart
lib/src/plugins/route/builders/route_builder.dart
lib/src/plugins/state/builders/state_builder.dart
lib/src/plugins/controller/controller_plugin.dart
lib/src/plugins/di/di_plugin.dart
lib/src/plugins/view/view_plugin.dart
```

### Documentation Template:

```dart
/// One-line description of what this class does.
///
/// Longer description with multiple sentences.
/// Can include [Link] to other classes.
///
/// Example:
/// ```dart
/// final builder = ClassName(outputDir: 'lib/src');
/// final result = await builder.generate(config);
/// ```
class ClassName {
  /// Creates a new [ClassName] instance.
  ///
  /// [outputDir] - Target directory for generated files
  /// [dryRun] - If true, preview without writing files
  ClassName({
    required this.outputDir,
    this.dryRun = false,
  });
}
```

---

## Priority 2: Tests (Effort: 4 hours)

### Create test files:

```
test/plugins/mock/mock_builder_test.dart       (30 min)
test/plugins/test/test_builder_test.dart      (30 min)
test/plugins/datasource/local_generator_test.dart       (30 min)
test/plugins/route/route_builder_test.dart  (30 min)
test/plugins/state/state_builder_test.dart   (30 min)
```

### Test Template:

```dart
void main() {
  group('MockBuilder', () {
    test('generates mock for entity', () async {
      final builder = MockBuilder(outputDir: '/tmp');
      final config = GeneratorConfig(name: 'Product');
      final files = await builder.generate(config);
      expect(files, isNotEmpty);
    }));

    test('handles list methods', () async {
      final builder = MockBuilder(outputDir: '/tmp');
      final config = GeneratorConfig(
        name: 'Product',
        methods: ['get', 'getList', 'create'],
      );
      final files = await builder.generate(config);
      expect(files.length, greaterThanOrEqualTo(1));
    }));
  });
}
```

---

## Priority 3: Null Safety (Effort: 1 hour)

### Replace `config.effectiveService!` with validation:

**File: lib/src/plugins/di/di_plugin.dart**

```dart
// BEFORE
DiPlugin({
  required GeneratorConfig config,
}) {
  final serviceName = config.effectiveService!;
  final serviceSnake = config.serviceSnake!;
}

// AFTER
DiPlugin({
  required GeneratorConfig config,
}) : _config = config {
  assert(
    config.hasService,
    'DiPlugin requires GeneratorConfig with hasService=true',
  );
}
```

### Locations to fix:

| File | Line | Pattern |
|------|------|---------|
| di_plugin.dart | 336-340 | `config.effectiveService!` |
| di_plugin.dart | 377-380 | `config.effectiveService!` |
| route_builder.dart | 178-179 | `config.effectiveService!` |
| test_builder.dart | 558 | `config.repo!` |

---

## Priority 4: Architecture Refactor (Effort: 8 hours)

### Split god classes (completed)

**Current:** Split into focused builders and modules
**Target:** Maintain <500 lines per file

**Completed structure:**

```
lib/src/plugins/mock/builders/
├── mock_builder.dart
├── mock_data_builder.dart
├── mock_data_source_builder.dart
├── mock_entity_graph_builder.dart
├── mock_entity_helper.dart
├── mock_type_helper.dart
└── mock_value_builder.dart

lib/src/plugins/usecase/generators/
├── custom_usecase_generator.dart
├── custom_usecase_generator_append.dart
├── custom_usecase_generator_core.dart
├── custom_usecase_generator_generate.dart
├── custom_usecase_generator_methods.dart
├── custom_usecase_generator_orchestrator.dart
└── custom_usecase_generator_polymorphic.dart

lib/src/plugins/controller/
├── controller_plugin.dart
├── controller_plugin_bodies.dart
├── controller_plugin_methods.dart
└── controller_plugin_utils.dart

lib/src/plugins/method_append/builders/
├── method_append_builder.dart
├── method_append_builder_append.dart
├── method_append_builder_create.dart
├── method_append_builder_find.dart
├── method_append_builder_imports.dart
└── method_append_builder_types.dart
```

### Refactoring Result:

Mock builder is now an orchestrator delegating to data, datasource, and entity graph builders.

### Files to split:

| File | Current Lines | Split Into | Target Lines |
|------|---------------|-----------|--------------|
| mock_builder.dart | 1433 | 7 files | ✅ |
| test_builder.dart | 1184 | 6 files | ✅ |
| implementation_generator.dart | 1162 | 4 files | ✅ |
| custom_usecase_generator.dart | 1025 | 7 files | ✅ |
| controller_plugin.dart | 976 | 4 files | ✅ |
| method_append_builder.dart | 944 | 6 files | ✅ |

---

## Priority 5: Naming Consistency (Effort: 30 min)

### Fix return types for consistency:

**File: lib/src/plugins/di/builders/registration_builder.dart**

```dart
// BEFORE
String buildRegistrationFile({
  required String functionName,
  required List<String> imports,
  required Block body,
}) {
  // returns String
}

// AFTER
Future<GeneratedFile> buildRegistrationFile({
  required String functionName,
  required List<String> imports,
  required Block body,
}) async {
  // returns Future<GeneratedFile>
}
```

---

## Priority 6: API Cleanup (Effort: 2 hours)

### Create GeneratorOptions class:

```dart
enum LogLevel {
  silent,
  info,
  verbose,
}

class GeneratorOptions {
  final bool dryRun;
  final bool force;
  final bool verbose;
  final LogLevel logLevel;

  const GeneratorOptions({
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
    this.logLevel = LogLevel.info,
  });

  const GeneratorOptions.dryRun()
      : this(dryRun: true, verbose: false, logLevel: LogLevel.silent);

  const GeneratorOptions.force()
      : this(force: true, verbose: true);
}
```

### Update all builders:

```dart
// BEFORE
class CacheBuilder {
  CacheBuilder({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  });
}

// AFTER
class CacheBuilder {
  final String outputDir;
  final GeneratorOptions options;

  CacheBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  });
}
```

---

## Quick Wins (Effort: 30 min)

### Add const to constructors:

```dart
// BEFORE
MockBuilder({
  required this.outputDir,
});

// AFTER
const MockBuilder({
  required this.outputDir,
});
```

### Files to update:

- mock_builder.dart
- test_builder.dart
- local_generator.dart
- route_builder.dart
- state_builder.dart

---

## Verification Commands

```bash
# Check documentation coverage (should be 0)
grep -L "^///" lib/src/plugins/**/*.dart 2>/dev/null | wc -l

# Check test coverage
flutter test test/plugins/ --verbose

# Check file lengths (should be <500)
find lib/src/plugins -name "*.dart" -exec wc -l {} \; | awk '$1 > 500 {print}'

# Dart analyze
dart analyze lib/src/plugins/

# Count Code() with strings (should be 1 - GraphQL)
grep -rn "Code(" lib/src/plugins --include="*.dart" | \
  grep -v "\.code\|CodeExpression\|emitLibrary\|///\|//" | wc -l
```

---

## Summary Checklist

| Priority | Task | Files | Effort | Status |
|----------|------|-------|--------|--------|
| 1 | Add documentation | 10 files | 2 hrs | ⬜ |
| 2 | Add tests | 5 files | 4 hrs | ✅ |
| 3 | Null safety fixes | 4 locations | 1 hr | ✅ |
| 4 | Split God classes | 3 files | 8 hrs | ✅ |
| 5 | Fix naming | 1 file | 30 min | ⬜ |
| 6 | API cleanup | All builders | 2 hrs | ⬜ |
| **Total** | | | **~18 hrs** | |

---

## Result After Completion

| Category | Before | After |
|----------|--------|-------|
| Documentation | 0% | 100% |
| Tests | 20% | 100% |
| Architecture | 70% | 100% |
| Null Safety | 75% | 100% |
| Naming | 80% | 100% |
| API Design | 75% | 100% |

**FINAL SCORE: 100%**

---

**Report generated:** 2026-02-11
**Next milestone:** 100% Code Quality
