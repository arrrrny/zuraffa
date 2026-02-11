# 100% Pure code_builder Migration Report

**Generated:** 2026-02-11
**Status:** REQUIRED
**Goal:** Zero string-based code generation

---

## Executive Summary

**Current State:** 48 `Code()` wrappers using strings
**Target State:** 0 `Code()` wrappers - pure AST construction

The migration to "100% code_builder" is **NOT COMPLETE**. While triple-quote templates have been removed, the codebase still uses 48 `Code()` wrappers that contain raw strings. This report identifies all patterns and provides conversion strategies.

---

## Files Requiring Migration

| Priority | File | Code() Count | Lines |
|----------|------|--------------|-------|
| P0 | `repository/generators/implementation_generator.dart` | 12 | Various |
| P1 | `datasource/builders/local_generator.dart` | 12 | Various |
| P2 | `datasource/builders/remote_generator.dart` | 8 | Various |
| P3 | `usecase/generators/custom_usecase_generator.dart` | 8 | 440-692 |
| P4 | `controller/controller_plugin.dart` | 3 | 180, 350, 507+ |
| P5 | `di/builders/registration_builder.dart` | 2 | 26, 53 |
| P6 | `usecase/generators/entity_usecase_generator.dart` | 1 | 311 |
| P7 | `usecase/generators/stream_usecase_generator.dart` | 1 | 120 |
| P8 | `view/builders/lifecycle_builder.dart` | 1 | 17 |

---

## Pattern Analysis & Conversions

### Pattern 1: Simple Return Statement

**File:** `datasource/builders/remote_generator.dart:70`

```dart
// CURRENT (HYBRID)
..body = Code('return Stream.value(true);'),

// TARGET (PURE)
..body = Block(
  (b) => b
    ..statements.add(
      refer('Stream').property('value').call([literalBool(true)]).returned.statement,
    ),
)
```

### Pattern 2: Array Join for Multi-line

**File:** `datasource/builders/remote_generator.dart:54-60`

```dart
// CURRENT (HYBRID)
..body = Code(
  [
    "logger.info('Initializing $dataSourceName');",
    '// TODO: Initialize remote connection, auth, etc.',
    "logger.info('$dataSourceName initialized');",
  ].join('\n'),
),

// TARGET (PURE)
..body = Block(
  (b) => b
    ..statements.add(
      refer('logger').property('info').call([
        literalString('Initializing $dataSourceName')
      ]).statement,
    )
    ..statements.add(
      refer('logger').property('info').call([
        literalString('$dataSourceName initialized')
      ]).statement,
    ),
)
```

### Pattern 3: Parameter Default Values

**File:** `controller/controller_plugin.dart:180`

```dart
// CURRENT (HYBRID)
..defaultTo = Code('const ListQueryParams()'),

// TARGET (PURE)
..defaultTo = refer('ListQueryParams').constInstance([]).code,
```

### Pattern 4: Inline Expression in Block

**File:** `controller/controller_plugin.dart:507`

```dart
// CURRENT (HYBRID)
Code('[...viewState.${entityCamel}List, created]'),

// TARGET (PURE)
refer('viewState').property(entityCamel).property('list').property('add').call([refer('created')]).statement
// OR for spread:
literalList([
  ...refer('viewState').property('${entityCamel}List').expression,
  refer('created'),
])
```

### Pattern 5: Body String Parameters

**File:** `usecase/generators/custom_usecase_generator.dart:441`

```dart
// CURRENT (HYBRID)
..body = Code(body),

// TARGET (PURE)
// Need to parse 'body' string and convert to AST
// This requires: parseMethodBody(String body) -> Block
```

### Pattern 6: Registration Body

**File:** `di/builders/registration_builder.dart:26`

```dart
// CURRENT (HYBRID)
..body = Code(registrationBody),

// TARGET (PURE)
// Need expression builder for getIt.registerLazySingleton<T>(...)
Block(
  (b) => b
    ..statements.add(
      refer('getIt').property('registerLazySingleton').call([
        refer('Type').call([])  // dynamic based on type
      ]).statement,
    ),
)
```

---

## Detailed File Analysis

### P0: `repository/generators/implementation_generator.dart`

**12 Code() wrappers at:**
- Lines 137, 155, 266, 281, 296, 314, 329, 344, 359
- Lines 570-620 (cache-aware bodies)

**Example Conversions:**

```dart
// Line 266: Simple return
// FROM:
..body = Code('return _dataSource.get(params);'),

// TO:
..body = Block(
  (b) => b
    ..statements.add(
      refer('_dataSource').property('get').call([
        refer('params')
      ]).returned.statement,
    ),
)

// Lines 570-620: Complex cache body
// FROM:
..statements.add(Code("if (await _cachePolicy.isValid('$baseCacheKey')) {"))

// TO:
..statements.add(
  refer('if').call([
    refer('_cachePolicy').property('isValid').call([
      literalString(baseCacheKey)
    ]).awaited
  ]).code,
)
```

---

### P1: `datasource/builders/local_generator.dart`

**12 Code() wrappers at:**
- Lines 54-60 (initialize body)
- Lines 484-519 (update/delete bodies)
- Lines 566+ (delete with list)

**Key Conversion - Update Body:**

```dart
// FROM (line 491):
Code(
  "final existing = _box.values.firstWhere((item) => item.${config.idField} == params.id, orElse: () => throw notFoundFailure('$entityName not found in cache'),);",
)

// TO (PURE):
..statements.add(
  declareFinal('existing').assign(
    refer('_box').property('values').property('firstWhere').call([
      Method((m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'item'))
        ..body = refer('item').property(config.idField).operator('==').refer('params.id').code,
      ).closure,
    ], {
      'orElse': Method((m) => m
        ..lambda = true
        ..body = refer('throw').call([
          refer('notFoundFailure').call([
            literalString('$entityName not found in cache')
          ])
        ]).code,
      ).closure,
    }),
  ).statement,
)
```

---

### P2: `datasource/builders/remote_generator.dart`

**8 Code() wrappers at:**
- Lines 54-60 (initialize)
- Lines 103-108 (get)
- Lines 127-132 (getList)
- Lines 151-156 (create)
- Lines 180 (update)
- Lines 204 (delete)
- Lines 227 (watch)
- Lines 250 (watchList)

**All follow Pattern 2 (Array Join) - convert to Block statements.**

---

### P3: `usecase/generators/custom_usecase_generator.dart`

**8 Code() wrappers at:**
- Lines 441, 463 (custom use case body)
- Lines 500-511 (execute body)
- Lines 526, 550 (execute body variations)
- Lines 589, 633 (stream body)
- Line 692

**Critical Issue:** This file passes `body` as a string parameter.

```dart
// CURRENT - takes body as string parameter
String buildUseCase({
  required String body,  // ← String body
}) {
  return Method(
    (m) => m
      ..body = Code(body),  // ← Wrapped in Code()
  );
}

// TARGET - take body as Block
String buildUseCase({
  required Block body,  // ← Block AST
}) {
  return Method(
    (m) => m
      ..body = body,  // ← Direct Block
  );
}
```

---

### P4: `controller/controller_plugin.dart`

**3+ Code() wrappers at:**
- Lines 180, 350: Parameter defaults
- Line 507: Inline expression
- Lines 578, 585, 662: Update state expressions
- Line 897: Default null

**Parameter Default Conversion:**

```dart
// FROM:
..defaultTo = Code('const ListQueryParams()'),

// TO:
..defaultTo = refer('ListQueryParams').constInstance([]).code,
```

---

### P5: `di/builders/registration_builder.dart`

**2 Code() wrappers:**
- Line 26: `Code(registrationBody)`
- Line 53: `Code(registrations.join('\n'))`

**Registration Body Conversion:**

```dart
// FROM:
..body = Code(registrationBody),
// registrationBody = "getIt.registerLazySingleton<MyType>(() => MyType());"

// TO:
..body = Block(
  (b) => b
    ..statements.add(
      refer('getIt').property('registerLazySingleton').call([
        refer('Type').call([]),  // Need dynamic type resolution
      ], {
        'factory': refer('Type').newInstance([]).closure,
      }).statement,
    ),
)
```

---

### P6-P8: Minor Files

| File | Line | Pattern |
|------|------|---------|
| `entity_usecase_generator.dart` | 311 | Simple body |
| `stream_usecase_generator.dart` | 120 | Execute body |
| `lifecycle_builder.dart` | 17 | Initial call |

**Lifecycle Conversion:**

```dart
// FROM:
initialCall.isEmpty ? const [] : [Code(initialCall)],

// TO:
initialCall.isEmpty
    ? const []
    : [refer(initialCall).statement],
```

---

## Helper Library Required

Create `lib/src/core/builder/helpers/ast_helpers.dart`:

```dart
library;

import 'package:code_builder/code_builder.dart';

class ASTHelper {
  /// Convert a method body string to Block
  static Block methodBodyToBlock(String body) {
    final lines = body.trim().split(';').where((l) => l.trim().isNotEmpty);
    return Block(
      (b) => b
        ..statements.addAll(
          lines.map((line) => lineToStatement(line.trim())),
        ),
    );
  }

  static Code lineToStatement(String line) {
    line = line.trim();
    if (line.startsWith('return ')) {
      final expr = line.substring(7).trim();
      return stringToExpression(expr).returned.statement;
    }
    if (line.startsWith('final ')) {
      return declareFromString(line).statement;
    }
    return Code(line);
  }

  static Expression stringToExpression(String expr) {
    // Parse common patterns
    if (expr.startsWith('await ')) {
      return stringToExpression(expr.substring(6)).awaited;
    }
    if (expr.contains('(')) {
      final method = expr.substring(0, expr.indexOf('('));
      final argsStart = expr.indexOf('(') + 1;
      final argsEnd = expr.lastIndexOf(')');
      final args = expr.substring(argsStart, argsEnd);
      return refer(method).call(args.split(',').map(stringToExpression).toList());
    }
    return refer(expr);
  }

  static Declaration declareFromString(String line) {
    // Parse: final Type name = value;
    final match = RegExp(r'final\s+(\w+)\s+(\w+)\s*=\s*(.+)').firstMatch(line);
    if (match != null) {
      final type = match.group(1)!;
      final name = match.group(2)!;
      final value = stringToExpression(match.group(3)!);
      return declareFinal(name).type(refer(type)).assign(value);
    }
    throw ArgumentError('Cannot parse declaration: $line');
  }

  /// Build a try-catch block
  static Block tryCatch({
    required Expression tryBody,
    required List<Code> catchBody,
    String? errorVar,
  }) {
    return Block(
      (b) => b
        ..statements.add(
          refer('try').call([]).code,
        )
        ..statements.add(tryBody.code)
        ..statements.add(
          refer('catch').call(errorVar != null ? [Parameter((p) => p..name = errorVar)] : []).code,
        )
        ..statements.addAll(catchBody),
    );
  }

  /// Build an if statement
  static Code ifStatement(Expression condition, List<Code> thenBody) {
    return refer('if').call([condition]).code;
  }

  /// Build a for loop
  static Block forLoop({
    required String varName,
    required Iterable<Expression> iterable,
    required List<Code> body,
  }) {
    return Block(
      (b) => b
        ..statements.add(
          refer('for').call([
            refer('var').call([literalString(varName)]),
          ]).code,
        )
        ..statements.addAll(body),
    );
  }
}
```

---

## Migration Strategy

### Phase 1: Low-Hanging Fruit (Easy Wins)

1. **Parameter defaults** - 3 files, 4 occurrences
   - `controller_plugin.dart:180, 350, 897`
   - Simple: `Code('const X()')` → `refer('X').constInstance([]).code`

2. **Simple returns** - 5 files, 10 occurrences
   - `remote_generator.dart:70`
   - `stream_usecase_generator.dart:120`
   - Pattern: `Code('return x;')` → Block with returned.statement

### Phase 2: Array Join Conversions

1. **remote_generator.dart** - 6 occurrences
   - `['line1', 'line2'].join('\n')` → Block with multiple statements

2. **lifecycle_builder.dart** - 1 occurrence
   - Handle conditional Code(initialCall)

### Phase 3: Complex Bodies

1. **local_generator.dart** - 12 occurrences
   - Update/delete with firstWhere patterns
   - Try-catch for cache operations

2. **implementation_generator.dart** - 12 occurrences
   - Cache-aware get/getList/create/update/delete
   - Complex control flow

### Phase 4: API Changes Required

1. **custom_usecase_generator.dart** - 8 occurrences
   - Change function signature from `String body` to `Block body`

2. **registration_builder.dart** - 2 occurrences
   - Need expression builder for getIt registrations
   - May require type-aware resolution

---

## Estimated Effort

| Phase | Files | Occurrences | Effort |
|-------|-------|-------------|--------|
| Phase 1 | 2 | 4 | 30 min |
| Phase 2 | 2 | 7 | 1 hour |
| Phase 3 | 2 | 24 | 4 hours |
| Phase 4 | 2 | 10 | 3 hours |
| **Total** | **8** | **48** | **~8.5 hours** |

---

## Verification

After migration, run:

```bash
# Count ALL Code() wrappers (expected: 0 for Dart code)
grep -rn "Code(" lib/src/plugins --include="*.dart" | \
  grep -v "///\|//\|CodeExpression\|.code\|emitLibrary\|const Code(" | \
  wc -l

# Expected: 0 (or 1 for non-Dart like comments)

# Alternative: Check for any string-based generation
grep -rn "join.*Code\|Code.*join" lib/src/plugins --include="*.dart"
```

---

## Success Criteria

| Criterion | Before | After |
|-----------|--------|-------|
| `Code()` wrappers | 48 | 0 |
| Pure AST construction | 0% | 100% |
| Type-safe generation | Partial | Complete |
| IDE refactoring support | Limited | Full |

---

## Conclusion

The migration to "100% pure code_builder" is **IN PROGRESS**. Approximately **8.5 hours** of work is required to eliminate all 48 `Code()` string wrappers and achieve truly type-safe AST-based code generation.

**Key deliverables:**
1. Create `ast_helpers.dart` library for common patterns
2. Convert parameter defaults (4 occurrences)
3. Convert array.join patterns (7 occurrences)
4. Convert complex bodies (24 occurrences)
5. Update APIs to accept Block instead of String (10 occurrences)

---

**Report generated:** 2026-02-11
**Next action:** Begin Phase 1 (parameter defaults)
