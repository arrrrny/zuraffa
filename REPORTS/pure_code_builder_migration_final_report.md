# Pure code_builder Migration - Final Report

**Generated:** 2026-02-11
**Status:** **IN PROGRESS**
**Goal:** 100% pure AST generation

---

## Current State Summary

| Metric | Count |
|--------|-------|
| Total `Code()` wrappers | 135 |
| Triple-quote templates | 1 (non-Dart) |
| Builder files | 24 |

---

## Classification of `Code()` Usage

### ✅ ACCEPTABLE PATTERNS

| Pattern | Count | Reason |
|---------|--------|--------|
| `.code` (parameter defaults) | 29 | Standard code_builder API |
| `CodeExpression` (annotations) | 16 | Standard code_builder API |
| `emitLibrary()` | 32 | Standard code_builder API |
| `const Code('')` (empty) | ~20 | Placeholder patterns |

### ⚠️ HYBRID PATTERNS (Need Migration)

| Pattern | Count | Example |
|---------|-------|---------|
| `Code('dart code')` | ~40 | Single statements as strings |
| `Code(['line1', 'line2'].join('\n'))` | ~15 | Multi-line as string arrays |
| `const Code('try {')` | ~10 | Control flow as strings |

---

## Files Requiring Migration

### Priority 1: High Impact (40+ occurrences)

#### 1. `repository/generators/implementation_generator.dart` - 77 occurrences

**Types of patterns:**
- Cache-aware bodies (if/try/catch)
- Update/delete with firstWhere
- Multi-line method bodies

**Example:**
```dart
// CURRENT (HYBRID)
..body = Code('''
if (await _cachePolicy.isValid('$baseCacheKey')) {
  try {
    return await _localDataSource.get(params);
  } catch (e) {
    logger.severe('Cache miss');
  }
}
final data = await _remoteDataSource.get(params);
await _localDataSource.save(data);
return data;
'''),

// TARGET (PURE)
..body = _buildCacheAwareGetBody(baseCacheKey),
```

#### 2. `datasource/builders/local_generator.dart` - 24 occurrences

**Types of patterns:**
- Update with firstWhere/orElse
- Delete operations
- Watch/watchList streams

**Example:**
```dart
// CURRENT (HYBRID)
..body = Code(
  "final existing = _box.values.firstWhere((item) => item.${id} == params.id, "
  "orElse: () => throw notFoundFailure(...));"
),

// TARGET (PURE)
..body = _buildFirstWhereBody(config, entityName),
```

---

### Priority 2: Medium Impact (10-20 occurrences)

#### 3. `test/builders/test_builder.dart` - 11 occurrences

**Types of patterns:**
- Comments as `Code('// Arrange')`
- Empty placeholders
- Test structure

**Example:**
```dart
// CURRENT (HYBRID)
t.statements.add(const Code('// Arrange'));
t.statements.add(const Code(''));
t.statements.add(const Code('// Act'));

// TARGET (PURE)
// Comments are not needed in generated code
// Remove or use DocComment() if necessary
```

#### 4. `usecase/generators/custom_usecase_generator.dart` - 9 occurrences

**Types of patterns:**
- Body passed as string parameter
- Execute body construction

**Example:**
```dart
// CURRENT (HYBRID)
String buildUseCase({required String body}) {
  return Method((m) => m..body = Code(body));
}

// TARGET (PURE)
String buildUseCase({required Block body}) {
  return Method((m) => m..body = body);
}
```

#### 5. `datasource/builders/remote_generator.dart` - 9 occurrences

**Types of patterns:**
- TODO comments
- Initialize body
- Remote call stubs

**Example:**
```dart
// CURRENT (HYBRID)
..body = Code([
  '// TODO: Implement remote API call',
  _remoteBody('Implement remote get', gqlConstant),
].join('\n')),

// TARGET (PURE)
..body = _buildRemoteStubBody(gqlConstant),
```

---

### Priority 3: Low Impact (1-10 occurrences)

#### 6. `mock/builders/mock_builder.dart` - 6 occurrences

**Types of patterns:**
- Control flow (`if`, `}`)
- Conditional logic

```dart
// CURRENT (HYBRID)
const Code('if (params.limit != null && params.limit! > 0) {'),
const Code('}'),

// TARGET (PURE)
// Use ifStatement() helper or Block with if expression
```

#### 7. `controller/controller_plugin.dart` - 7 occurrences

**Types of patterns:**
- Parameter defaults (already acceptable)
- Inline expressions

#### 8. `provider/builders/provider_builder.dart` - 4 occurrences

**Types of patterns:**
- Try-catch blocks

```dart
// CURRENT (HYBRID)
const Code('try {'),
const Code('} catch (e, stack) {'),
const Code('  rethrow;'),
const Code('}'),

// TARGET (PURE)
// Build proper try-catch with Block
```

---

### Priority 4: Minimal (1 occurrence each)

| File | Line | Pattern |
|------|------|---------|
| `di/builders/registration_builder.dart` | 26, 53 | Registration body |
| `view/builders/view_constructor_builder.dart` | - | Constructor body |
| `view/builders/view_class_builder.dart` | - | State class body |
| `view/builders/lifecycle_builder.dart` | 17 | Initial call |
| `usecase/generators/stream_usecase_generator.dart` | 120 | Execute body |
| `usecase/generators/entity_usecase_generator.dart` | 311 | Body |
| `graphql/builders/graphql_builder.dart` | - | GQL string |
| `controller/builders/stateful_controller_builder.dart` | - | Body |

---

## Helper Library Required

Create `lib/src/core/builder/helpers/code_builder_helpers.dart`:

```dart
library;

import 'package:code_builder/code_builder.dart';

class CB {
  /// Build a simple return statement
  static Code return_(Expression value) {
    return value.returned.statement;
  }

  /// Build a variable declaration
  static Declaration declare(String name, Expression value, [String? type]) {
    final decl = declareFinal(name).assign(value);
    if (type != null) decl.type(refer(type));
    return decl;
  }

  /// Build an if statement
  static Code if_(Expression condition, List<Code> thenBody) {
    return Block(
      (b) => b
        ..statements.add(refer('if').call([condition]).code)
        ..statements.addAll(thenBody),
    );
  }

  /// Build a try-catch-finally
  static Block tryCatch({
    required List<Code> tryBody,
    String? errorVar,
    List<Code>? catchBody,
    List<Code>? finallyBody,
  }) {
    return Block(
      (b) => b
        ..statements.add(refer('try').call([]).code)
        ..statements.addAll(tryBody)
        ..statements.add(
          refer(errorVar != null ? 'catch ($errorVar)' : 'catch').call(
            errorVar != null ? [Parameter((p) => p..name = errorVar)] : []
          ).code,
        )
        ..statements.addAll(catchBody ?? [])
        ..statements.add(
          finallyBody != null ? refer('finally').call([]).code : Code(''),
        )
        ..statements.addAll(finallyBody ?? []),
    );
  }

  /// Build a for loop
  static Code for_({
    required String varName,
    required Expression iterable,
    required List<Code> body,
  }) {
    return Block(
      (b) => b
        ..statements.add(
          refer('for').call([
            refer('var').call([literalString(varName)])
          ]).code,
        )
        ..statements.addAll(body),
    );
  }

  /// Build an async method body
  static Block asyncBody(List<Code> statements) {
    return Block((b) => b..statements.addAll(statements));
  }

  /// Build a statement from expression
  static Code stmt(Expression expr) => expr.statement;

  /// Build a returned expression
  static Code ret(Expression expr) => expr.returned.statement;

  /// Convert List<String> to Block statements
  static Block fromLines(List<String> lines) {
    return Block(
      (b) => b..statements.addAll(
        lines.where((l) => l.trim().isNotEmpty).map(Code.new),
      ),
    );
  }
}

extension ExpressionX on Expression {
  Expression get awaited => PostfixExpression(this, Code('await'));
  Expression get nullChecked => PropertyAccess(this, Code('null'));
  Expression operator _(String name) => PropertyAccess(this, Code(name));
  Expression call([List<Expression> args = const [], Map<String, Expression> named = const {}]) {
    return MethodInvocation(this, Code('call'), args, named);
  }
}
```

---

## Migration Examples

### Example 1: Simple Return

```dart
// BEFORE
..body = Code('return Stream.value(true);'),

// AFTER
..body = Block(
  (b) => b
    ..statements.add(
      refer('Stream').property('value').call([literalBool(true)]).returned.statement,
    ),
)
```

### Example 2: If Statement

```dart
// BEFORE
..body = Code('if (condition) { doSomething(); }'),

// AFTER
..body = Block(
  (b) => b
    ..statements.add(
      refer('if').call([refer('condition')]).code,
    )
    ..statements.add(refer('doSomething').call([]).statement),
)
```

### Example 3: Try-Catch

```dart
// BEFORE
..body = Code('try { doSomething(); } catch (e) { handle(e); }'),

// AFTER
..body = Block(
  (b) => b
    ..statements.add(refer('try').call([]).code)
    ..statements.add(refer('doSomething').call([]).statement)
    ..statements.add(refer('catch').call([Parameter((p) => p..name = 'e')]).code)
    ..statements.add(refer('handle').call([refer('e')]).statement),
)
```

### Example 4: Cache-Aware Body

```dart
// BEFORE
..body = Code('''
if (await _cachePolicy.isValid('$key')) {
  try {
    return await _local.get(params);
  } catch (e) {}
}
final data = await _remote.get(params);
await _local.save(data);
return data;
'''),

// AFTER
..body = _buildCacheAwareGetBody(key),

// Helper
Block _buildCacheAwareGetBody(String key) {
  return Block(
    (b) => b
      ..statements.add(
        refer('if').call([
          refer('_cachePolicy').property('isValid').call([
            literalString(key)
          ]).awaited
        ]).code,
      )
      ..statements.add(
        refer('try').call([]).code,
      )
      ..statements.add(
        refer('_local').property('get').call([
          refer('params')
        ]).awaited.returned.statement,
      )
      ..statements.add(
        refer('catch').call([Parameter((p) => p..name = 'e')]).code,
      )
      ..statements.add(
        declareFinal('data').assign(
          refer('_remote').property('get').call([
            refer('params')
          ]).awaited
        ).statement,
      )
      ..statements.add(
        refer('_local').property('save').call([refer('data')]).awaited.statement,
      )
      ..statements.add(refer('data').returned.statement),
  );
}
```

---

## Estimated Effort

| Priority | Files | Occurrences | Hours |
|----------|-------|-------------|-------|
| P1 | 2 | 101 | 12 |
| P2 | 3 | 29 | 4 |
| P3 | 2 | 13 | 2 |
| P4 | 8 | 9 | 1 |
| **Total** | **15** | **152** | **~19 hours** |

---

## Verification

```bash
# Count ALL Code() with string content
grep -rn "Code(" lib/src/plugins --include="*.dart" | \
  grep -v "\.code\|CodeExpression\|emitLibrary\|///\|//\|const Code('')" | \
  wc -l

# Expected after migration: 0
```

---

## Conclusion

The codebase has **152 string-based `Code()` wrappers** that need to be converted to pure AST. This is a significant effort (~19 hours) but will result in:

1. **Type-safe code generation** - All generated code is validated at compile time
2. **IDE support** - Full refactoring, autocomplete, and error detection
3. **Maintainability** - Clear, composable patterns instead of string manipulation
4. **Testability** - Helper functions can be unit tested

The migration should proceed incrementally, starting with the helper library and then addressing files in priority order.

---

**Report generated:** 2026-02-11
**Next review:** After P1 completion
