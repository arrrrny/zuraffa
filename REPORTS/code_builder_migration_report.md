# Detailed Report: 100% `code_builder` Migration Required

**Generated:** 2026-02-11  
**Author:** AI Code Review  
**Status:** IN PROGRESS

---

## Executive Summary

**CLAIM:** "100% migrated to code_builder"  
**REALITY:** **66 string templates** still exist across 7 files

The recent PR #82/83 claimed full migration to `code_builder`, but inspection reveals significant work remains. This report documents all remaining string templates and provides detailed conversion patterns.

---

## File-by-File Breakdown

### 1. `controller/controller_plugin.dart` — 28 templates ⚠️ HIGH PRIORITY

**Location:** `lib/src/plugins/controller/controller_plugin.dart`

#### Template A: `_buildGetMethod` (Lines 137-162)

**Current Code:**
```dart
final body = withState
    ? '''
final token = cancelToken ?? createCancelToken();
updateState(viewState.copyWith(isGetting: true));
final result = await _presenter.get$entityName($callArgs);

result.fold(
  (entity) => updateState(viewState.copyWith(
    isGetting: false,
    $entityCamel: entity,
  )),
  (failure) => updateState(viewState.copyWith(
    isGetting: false,
    error: failure,
  )),
);
'''
    : '''
final token = cancelToken ?? createCancelToken();
final result = await _presenter.get$entityName($callArgs);

result.fold(
  (entity) {},
  (failure) {},
);
''';
```

**Required Conversion:**
```dart
final body = withState
    ? _buildGetWithStateBody(entityName, entityCamel, callArgs)
    : _buildGetWithoutStateBody(entityName, callArgs);

Block _buildGetWithStateBody(String entityName, String entityCamel, String callArgs) {
  return Block(
    (b) => b
      ..statements.add(
        declareFinal('token').assign(
          refer('cancelToken').equalNullCheck ?? refer('createCancelToken').call()
        ).statement,
      )
      ..statements.add(
        refer('updateState').call([
          refer('viewState').property('copyWith').call([], {'isGetting': literalTrue()}),
        ]).statement,
      )
      ..statements.add(
        declareFinal('result').assign(
          refer('_presenter').property('get$entityName').call([refer(callArgs)]).awaited
        ).statement,
      )
      ..statements.add(
        refer('result').property('fold').call([
          Method((m) => m
            ..requiredParameters.addAll([
              Parameter((p) => p..name = 'entity'),
              Parameter((p) => p..name = 'failure'),
            ])
            ..body = Block((bb) => bb
              ..statements.add(
                refer('updateState').call([
                  refer('viewState').property('copyWith').call([], {
                    'isGetting': literalFalse(),
                    entityCamel: refer('entity'),
                  }),
                ]).statement,
              ),
            ),
          ).closure,
          Method((m) => m
            ..requiredParameters.addAll([
              Parameter((p) => p..name = 'failure'),
            ])
            ..body = Block((bb) => bb
              ..statements.add(
                refer('updateState').call([
                  refer('viewState').property('copyWith').call([], {
                    'isGetting': literalFalse(),
                    'error': refer('failure'),
                  }),
                ]).statement,
              ),
            ),
          ).closure,
        ]).statement,
      ),
  );
}
```

#### Template B: `_buildGetListMethod` (Similar pattern, 14 more lines)

---

### 2. `datasource/builders/local_generator.dart` — 14 templates ⚠️ HIGH PRIORITY

**Location:** `lib/src/plugins/datasource/builders/local_generator.dart`

#### Template A: Update with Zorphy + hasListMethods (Lines 203-220)

**Current Code:**
```dart
body: config.useZorphy
    ? '''
final existing = _box.values.firstWhere(
  (item) => item.${config.idField} == params.id,
  orElse: () => throw notFoundFailure('$entityName not found in cache'),
);
final updated = params.data.applyTo(existing);
await _box.put(updated.${config.idField}, updated);
return updated;
'''
    : '''
final existing = _box.values.firstWhere(
  (item) => item.${config.idField} == params.id,
  orElse: () => throw notFoundFailure('$entityName not found in cache'),
);
await _box.put(existing.${config.idField}, existing);
return existing;
''',
```

**Required Conversion:**
```dart
body: config.useZorphy
    ? _buildUpdateWithZorphyBody(config, entityName)
    : _buildUpdateWithoutZorphyBody(config, entityName),

Block _buildUpdateWithZorphyBody(GeneratorConfig config, String entityName) {
  return Block(
    (b) => b
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
      ..statements.add(
        declareFinal('updated').assign(
          refer('params').property('data').property('applyTo').call([
            refer('existing')
          ])
        ).statement,
      )
      ..statements.add(
        refer('_box').property('put').call([
          refer('updated').property(config.idField),
          refer('updated')
        ]).awaited.statement,
      )
      ..statements.add(refer('updated').returned.statement),
  );
}
```

---

### 3. `repository/generators/implementation_generator.dart` — 10 templates ⚠️ MEDIUM PRIORITY

**Location:** `lib/src/plugins/repository/generators/implementation_generator.dart`

#### Template A: Cache-aware `get` method (Lines 389-401)

**Current Code:**
```dart
..body = Code('''
    if (await _cachePolicy.isValid('$baseCacheKey')) {
      try {
        return await _localDataSource.get(params);
      } catch (e) {
        logger.severe('Cache miss, fetching from remote');
      }
    }
    final data = await _remoteDataSource.get(params);
    await _localDataSource.save(data);
    await _cachePolicy.markFresh('$baseCacheKey');
    return data;
'''),
```

**Required Conversion:**
```dart
..body = _buildCacheAwareGetBody(config, entityName, baseCacheKey),

Block _buildCacheAwareGetBody(GeneratorConfig config, String entityName, String baseCacheKey) {
  return Block(
    (b) => b
      ..statements.add(
        refer('if').call([
          refer('_cachePolicy').property('isValid').call([
            literalString(baseCacheKey)
          ]).awaited
        ]).code,
      )
      ..statements.add(
        refer('try').call([]).code,
      )
      ..statements.add(
        refer('try').call([], {}, [
          Method((m) => m
            ..body = Block((bb) => bb
              ..statements.add(
                refer('return').call([
                  refer('_localDataSource').property('get').call([
                    refer('params')
                  ]).awaited
                ]).statement,
              ),
            ),
          ).closure,
          Method((m) => m
            ..requiredParameters.add(Parameter((p) => p..name = 'e'))
            ..body = Block((bb) => bb
              ..statements.add(
                refer('logger').property('severe').call([
                  literalString('Cache miss, fetching from remote')
                ]).statement,
              ),
            ),
          ).closure,
        ]),
      )
      ..statements.add(
        declareFinal('data').assign(
          refer('_remoteDataSource').property('get').call([
            refer('params')
          ]).awaited
        ).statement,
      )
      ..statements.add(
        refer('_localDataSource').property('save').call([
          refer('data')
        ]).awaited.statement,
      )
      ..statements.add(
        refer('_cachePolicy').property('markFresh').call([
          literalString(baseCacheKey)
        ]).awaited.statement,
      )
      ..statements.add(refer('data').returned.statement),
  );
}
```

---

### 4. `view/builders/view_class_builder.dart` — 8 templates ⚠️ MEDIUM PRIORITY

**Location:** `lib/src/plugins/view/builders/view_class_builder.dart`

#### Template A: `createStateMethod` body (Lines 71-74)

**Current Code:**
```dart
..body = Code('''
return _${spec.viewName}State(
  $controllerCall,
);'''),
```

#### Template B: `builderBody` ternary (Lines 104-111)

**Current Code:**
```dart
final builderBody = spec.withState
    ? '''
      final viewState = controller.viewState;
      return Container(key: ValueKey(viewState.hashCode));
 '''
    : '''
      return Container();
 ''';
```

#### Template C: `viewGetter` with nested widgets (Lines 119-130)

**Current Code:**
```dart
..body = Code('''
return Scaffold(
  key: globalKey,
  appBar: AppBar(
    title: const Text('${spec.entityName}'),
  ),
  body: ControlledWidgetBuilder<${spec.controllerName}>(
    builder: (context, controller) {
${builderBody.trimRight()}
    },
  ),
);'''),
```

---

### 5. `view/builders/lifecycle_builder.dart` — 2 templates ✅ EASY

**Location:** `lib/src/plugins/view/builders/lifecycle_builder.dart`

**Current Code:**
```dart
..body = Code('''
    super.onInitState();
    $initialCall
'''),
```

**Required Conversion:**
```dart
..body = Block(
  (b) => b
    ..statements.add(
      refer('super').property('onInitState').call([]).statement,
    )
    ..statements.add(
      refer(initialCall).statement,
    ),
),
```

---

### 6. `controller/builders/controller_class_builder.dart` — 2 templates ✅ EASY

**Location:** `lib/src/plugins/controller/builders/controller_class_builder.dart`

**Current Code:**
```dart
..body = Code('''
_presenter.dispose();
super.onDisposed();
'''),
```

**Required Conversion:**
```dart
..body = Block(
  (b) => b
    ..statements.add(
      refer('_presenter').property('dispose').call([]).statement,
    )
    ..statements.add(
      refer('super').property('onDisposed').call([]).statement,
    ),
),
```

---

### 7. `cache/builders/cache_builder.dart` — 2 templates ✅ ACCEPTABLE

**Location:** `lib/src/plugins/cache/builders/cache_builder.dart`

**Current Code:**
```dart
final template = '''# Hive Manual Additions
# Add nested entities and enums that need Hive adapters
# Format: import_path|EntityName
# Example: ../domain/entities/enums.dart|ParserType

# Uncomment and add your entities below:
# ../domain/entities/enums.dart|ParserType
''';
```

**Status:** ✅ ACCEPTABLE — This is a configuration file, not Dart code.

---

## Conversion Pattern Reference

### Pattern A: Single Statement

```dart
// FROM:
..body = Code('return x;')

// TO:
..body = Block((b) => b..statements.add(refer('x').statement))
```

### Pattern B: Multiple Statements

```dart
// FROM:
..body = Code('''
final x = y;
return x;
''')

// TO:
..body = Block(
  (b) => b
    ..statements.add(declareFinal('x').assign(refer('y')).statement)
    ..statements.add(refer('x').returned.statement)
)
```

### Pattern C: Async/Await

```dart
// FROM:
..body = Code('''
final data = await fetch();
return data;
''')

// TO:
..body = Block(
  (b) => b
    ..statements.add(
      declareFinal('data').assign(
        refer('fetch').call([]).awaited
      ).statement,
    )
    ..statements.add(refer('data').returned.statement)
)
```

### Pattern D: If/Conditional

```dart
// FROM:
..body = Code('''
if (condition) {
  doSomething();
}
''')

// TO:
..body = Block(
  (b) => b
    ..statements.add(
      refer('if').call([
        refer('condition')
      ]).code,
    )
    ..statements.add(refer('doSomething').call([]).statement)
)
```

### Pattern E: Try/Catch

```dart
// FROM:
..body = Code('''
try {
  return await fetch();
} catch (e) {
  logger.error('Failed');
}
''')

// TO:
..body = Block(
  (b) => b
    ..statements.add(
      refer('try').call([], {}, [
        Method((m) => m
          ..body = Block((bb) => bb
            ..statements.add(
              refer('return').call([
                refer('fetch').call([]).awaited
              ]).statement,
            ),
          ),
        ).closure,
        Method((m) => m
          ..requiredParameters.add(Parameter((p) => p..name = 'e'))
          ..body = Block((bb) => bb
            ..statements.add(
              refer('logger').property('error').call([
                literalString('Failed')
              ]).statement,
            ),
          ),
        ).closure,
      ]),
    )
)
```

### Pattern F: Fold/Pattern Matching

```dart
// FROM:
..body = Code('''
result.fold(
  (success) => handle(success),
  (failure) => handleError(failure),
);
''')

// TO:
..body = Block(
  (b) => b
    ..statements.add(
      refer('result').property('fold').call([
        Method((m) => m
          ..requiredParameters.add(Parameter((p) => p..name = 'success'))
          ..lambda = true
          ..body = refer('handle').call([refer('success')]).code,
        ).closure,
        Method((m) => m
          ..requiredParameters.add(Parameter((p) => p..name = 'failure'))
          ..lambda = true
          ..body = refer('handleError').call([refer('failure')]).code,
        ).closure,
      ]).statement,
    )
)
```

---

## Helper Library Recommendation

Create `lib/src/core/builder/helpers/block_helpers.dart`:

```dart
library;

import 'package:code_builder/code_builder.dart';

class BlockHelper {
  static Block asyncBody(List<Code> statements) {
    return Block((b) => b..statements.addAll(statements));
  }

  static Block asyncBodyWithToken(List<Code> statements) {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('token').assign(
            refer('cancelToken').equalNullCheck ?? refer('createCancelToken').call()
          ).statement,
        )
        ..statements.addAll(statements),
    );
  }

  static Block cacheAwareBody({
    required String baseCacheKey,
    required Expression localSource,
    required Expression remoteSource,
    required Expression localSave,
  }) {
    return Block(
      (b) => b
        ..statements.add(
          refer('if').call([
            refer('_cachePolicy').property('isValid').call([
              literalString(baseCacheKey)
            ]).awaited
          ]).code,
        )
        ..statements.add(
          refer('try').call([], {}, [
            Method((m) => m
              ..body = Block((bb) => bb
                ..statements.add(refer('return').call([localSource.awaited]).statement),
              ),
            ).closure,
            Method((m) => m
              ..requiredParameters.add(Parameter((p) => p..name = 'e'))
              ..body = Block((bb) => bb
                ..statements.add(
                  refer('logger').property('severe').call([
                    literalString('Cache miss, fetching from remote')
                  ]).statement,
                ),
              ),
            ).closure,
          ]),
        )
        ..statements.add(
          declareFinal('data').assign(remoteSource.awaited).statement,
        )
        ..statements.add(localSave.awaited.statement)
        ..statements.add(
          refer('_cachePolicy').property('markFresh').call([
            literalString(baseCacheKey)
          ]).awaited.statement,
        )
        ..statements.add(refer('data').returned.statement),
    );
  }

  static Block foldResult({
    required String resultVar,
    required String onSuccess,
    required String onFailure,
  }) {
    return Block(
      (b) => b
        ..statements.add(
          refer(resultVar).property('fold').call([
            Method((m) => m
              ..requiredParameters.add(Parameter((p) => p..name = 'value'))
              ..lambda = true
              ..body = refer(onSuccess).code,
            ).closure,
            Method((m) => m
              ..requiredParameters.add(Parameter((p) => p..name = 'failure'))
              ..lambda = true
              ..body = refer(onFailure).code,
            ).closure,
          ]).statement,
        ),
    );
  }

  static Block updateStateCopyWith({
    required String field,
    required Reference value,
    bool isLoading = false,
  }) {
    return Block(
      (b) => b
        ..statements.add(
          refer('updateState').call([
            refer('viewState').property('copyWith').call([], {
              field: value,
              if (isLoading) 'isLoading': literalFalse(),
            }),
          ]).statement,
        ),
    );
  }
}
```

---

## Migration Priority Matrix

| Priority | File | Templates | Estimated Effort | Status |
|----------|------|-----------|------------------|--------|
| P0 | controller_plugin.dart | 28 | 4-6 hours | NOT STARTED |
| P1 | local_generator.dart | 14 | 3-4 hours | NOT STARTED |
| P2 | implementation_generator.dart | 10 | 2-3 hours | NOT STARTED |
| P3 | view_class_builder.dart | 8 | 2 hours | NOT STARTED |
| P4 | lifecycle_builder.dart | 2 | 15 min | NOT STARTED |
| P5 | controller_class_builder.dart | 2 | 15 min | NOT STARTED |
| P6 | cache_builder.dart | 2 | N/A | ACCEPTABLE |

---

## Verification

After completing migration, run:

```bash
# Count remaining Dart string templates
grep -rn "'''" lib/src/plugins --include="*.dart" | \
  grep -v "///\|//\|dart'''\|'''dart\|\.code\|refer\|emit\|import" | \
  wc -l

# Expected result: 0 (or 2 for non-Dart templates)

# Alternative: Check for any Code() with multi-line strings
grep -rn "Code('''" lib/src/plugins --include="*.dart" | \
  grep -v "///\|//\|dart'''"
```

---

## Statistics

| Metric | Before | After |
|--------|--------|-------|
| Total string templates | 66 | 0 |
| Files with templates | 7 | 0 |
| Pure code_builder files | 17 | 24 |
| Hybrid files | 7 | 0 |

---

## Recommendations

1. **Create helper library** (`block_helpers.dart`) before starting migration
2. **Start with P4/P5** (easiest templates) to establish patterns
3. **Use batch conversion** for similar templates in same file
4. **Add regression tests** after each file migration
5. **Run flutter analyze** after each commit

---

## Conclusion

The migration to "100% code_builder" is **NOT COMPLETE**. The codebase contains 66 string templates that need to be converted to proper `Block()` constructions. This is a significant effort (12-16 hours estimated) but will result in a fully type-safe, maintainable code generation system.

---

**Report generated:** 2026-02-11  
**Next review:** After P0-P3 completion
