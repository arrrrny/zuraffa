part of 'test_builder.dart';

extension TestBuilderHelpers on TestBuilder {
  Future<String> _resolvePackageName(String projectRoot) async {
    String packageName = 'your_app';
    try {
      final pubspecPath = path.join(projectRoot, 'pubspec.yaml');
      if (await fileSystem.exists(pubspecPath)) {
        final content = await fileSystem.read(pubspecPath);
        final lines = content.split('\n');
        for (final line in lines) {
          if (line.trim().startsWith('name:')) {
            packageName = line.split(':')[1].trim();
            break;
          }
        }
      }
    } catch (_) {}
    return packageName;
  }

  Future<String> _findUseCaseDomain(
    String usecaseSnake,
    String defaultDomain,
  ) async {
    final usecasesDir = path.join(outputDir, 'domain', 'usecases');
    if (await fileSystem.exists(usecasesDir)) {
      final items = await fileSystem.list(usecasesDir);
      for (final item in items) {
        if (await fileSystem.isDirectory(item)) {
          final foundDomain = path.basename(item);
          final useCaseFile = path.join(item, '${usecaseSnake}_usecase.dart');
          if (await fileSystem.exists(useCaseFile)) {
            return foundDomain;
          }

          if (usecaseSnake.endsWith('_use_case')) {
            final shortSnake = usecaseSnake.substring(
              0,
              usecaseSnake.length - 9,
            );
            final shortUseCaseFile = path.join(
              item,
              '${shortSnake}_usecase.dart',
            );
            if (await fileSystem.exists(shortUseCaseFile)) {
              return foundDomain;
            }
          }
        }
      }
    }
    return defaultDomain;
  }

  /// Generates a `Fake{Name}` class that [implements] [interfaceName] and
  /// returns a sensible default value for every abstract method.
  ///
  /// Uses the analyzer to parse [filePath], find the first class declaration,
  /// and emit `@override` method stubs whose bodies return:
  /// - `Future.value(<default>)` for async methods
  /// - `Stream.value(<default>)` for stream methods
  /// - `<default>` for synchronous methods
  /// - empty body for void methods
  ///
  /// [entityTypes] — entity names in scope, used to construct sample values
  /// (e.g. `Product()` for an entity-typed return).
  Future<Class?> _generateFakeClassForDependency({
    required String className,
    required String interfaceName,
    required String filePath,
    required String packageName,
    required String projectRoot,
    required Set<String> entityTypes,
  }) async {
    final parser = const FileParser();
    final result = await parser.parseFile(filePath, fileSystem: fileSystem);
    final unit = result.unit;
    if (unit == null) return null;

    ast.ClassDeclaration? targetClass;
    for (final node in unit.declarations) {
      if (node is ast.ClassDeclaration &&
          node.namePart.typeName.lexeme == interfaceName) {
        targetClass = node;
        break;
      }
    }
    if (targetClass == null) return null;

    final methodBodies = <String>[];
    for (final member in targetClass.body.members) {
      if (member is ast.MethodDeclaration && member.isAbstract) {
        final methodStr = _generateFakeMethod(member, entityTypes);
        if (methodStr.isNotEmpty) methodBodies.add(methodStr);
      }
    }

    return Class(
      (c) => c
        ..name = className
        ..implements.add(refer(interfaceName))
        ..methods.add(Method((m) => m
          ..body = Code(methodBodies.join('\n\n')))),
    );
  }

  /// Generates a single `@override` method stub string for [method].
  /// Returns an empty string for constructors, getters, setters, and
  /// operators (only normal methods are emitted).
  String _generateFakeMethod(
    ast.MethodDeclaration method,
    Set<String> entityTypes,
  ) {
    final name = method.name.lexeme;
    final returnType = method.returnType;

    // Only emit normal methods (not constructors, getters, setters).
    if (method.isGetter || method.isSetter) {
      return '';
    }

    final returnTypeStr = returnType?.toString() ?? 'dynamic';

    if (!method.isAbstract) return ''; // Abstract methods only.

    final bodyStr = returnTypeStr == 'void'
        ? '{}'
        : '{ return ${_defaultValueForType(returnTypeStr, entityTypes)}; }';

    final params = <String>[];
    for (final p in method.parameters?.parameters ?? []) {
      params.add('${p.declaredElement?.type} ${p.declaredElement?.name}');
    }

    return '@override\n$returnTypeStr $name(${params.join(', ')}) $bodyStr';
  }

  /// Determines the raw Dart expression string for a default value of
  /// [returnType] — handles `Future<T>`, `Stream<T>`, nullable types,
  /// collection types, entity types, and built-in primitives.
  String _defaultValueForType(String returnType, Set<String> entityTypes) {
    // Future<T> → Future.value(<innerDefault>)
    if (returnType.startsWith('Future<') && returnType.endsWith('>')) {
      final inner = _extractInnerType(returnType);
      return 'Future.value(${_defaultValueForType(inner, entityTypes)})';
    }
    // Stream<T> → Stream.value(<innerDefault>)
    if (returnType.startsWith('Stream<') && returnType.endsWith('>')) {
      final inner = _extractInnerType(returnType);
      return 'Stream.value(${_defaultValueForType(inner, entityTypes)})';
    }
    // T? → null
    if (returnType.endsWith('?')) {
      return 'null';
    }
    // List<T> → []
    if (returnType.startsWith('List<') && returnType.endsWith('>')) {
      return '[]';
    }
    // Map<K,V> → {}
    if (returnType.startsWith('Map<') && returnType.endsWith('>')) {
      return '{}';
    }
    // Entity types in scope → EntityName()
    if (entityTypes.contains(returnType)) {
      return '$returnType()';
    }
    // Dart built-in defaults
    return switch (returnType) {
      'String' => "'x'",
      'int' => '0',
      'double' => '0.0',
      'bool' => 'false',
      'dynamic' || 'Object' => 'null',
      'void' => '',
      _ => 'null',
    };
  }

  /// Extracts the first type argument from a generic like
  /// `Future<List<Product>>` → `List<Product>`.
  String _extractInnerType(String type) {
    final firstOpen = type.indexOf('<');
    final lastClose = type.lastIndexOf('>');
    if (firstOpen >= 0 && lastClose > firstOpen) {
      return type.substring(firstOpen + 1, lastClose).trim();
    }
    return type;
  }

  Expression _generateCustomTestBody(
    GeneratorConfig config,
    String paramsType,
    String useCaseType,
  ) {
    final callArgs = paramsType == 'NoParams'
        ? [refer('NoParams').constInstance([])]
        : [_getDefaultValueForType(paramsType, config.name)];

    final testContent = Block((t) {
      if (useCaseType == 'background') {
        t.statements.add(
          declareFinal('result')
              .assign(refer('useCase').property('buildTask').call(callArgs))
              .statement,
        );
        t.statements.add(
          refer('expect').call([
            refer('result'),
            refer('isA').call([], {}, [refer('BackgroundTask')]),
          ]).statement,
        );
      } else if (useCaseType == 'stream') {
        t.statements.add(
          declareFinal(
            'result',
          ).assign(refer('useCase').call(callArgs)).statement,
        );
        t.statements.add(
          refer('expectLater')
              .call([
                refer('result'),
                refer('emits').call([
                  refer('isA').call([], {}, [refer('Success')]),
                ]),
              ])
              .awaited
              .statement,
        );
      } else {
        t.statements.add(
          declareFinal('result')
              .assign(refer('useCase').property('call').call(callArgs).awaited)
              .statement,
        );
        t.statements.add(
          refer('expect').call([
            refer('result').property('isSuccess'),
            literalBool(true),
          ]).statement,
        );
      }
    });

    return refer('test').call([
      literalString(
        useCaseType == 'stream'
            ? 'should emit values from stream'
            : 'should return Success',
      ),
      testContent.toClosure(asAsync: true),
    ]);
  }

  Expression _getDefaultValueForType(String type, String name) {
    return switch (type) {
      'String' => literalString('1'),
      'int' => literal(1),
      'double' => literal(1.0),
      'bool' => literalBool(true),
      'dynamic' => literalNull,
      _ => refer('t$type'),
    };
  }

  // #354: detect whether the projectRoot's pubspec.yaml declares a Flutter
  // dependency (`flutter: sdk: flutter`). Pure-Dart apps (`zfa setup --dart`)
  // cannot import `package:flutter_test/flutter_test.dart` or
  // `package:zuraffa_flutter/zuraffa_flutter.dart` — they only wire
  // `test` + `zuraffa`. Falls back to false when pubspec.yaml
  // is missing or unreadable, matching DependencyWirer.isFlutterProject's
  // conservative default. Result is cached per TestBuilder instance.
  Future<bool> _isFlutterProject(String projectRoot) async {
    if (_cachedIsFlutterProject != null) {
      return _cachedIsFlutterProject!;
    }
    bool isFlutter = false;
    try {
      final pubspecPath = path.join(projectRoot, 'pubspec.yaml');
      if (await fileSystem.exists(pubspecPath)) {
        final content = await fileSystem.read(pubspecPath);
        isFlutter = DependencyWirer.isFlutterProject(content);
      }
    } catch (_) {
      // Mirror DependencyWirer: unreadable pubspec -> not Flutter.
    }
    _cachedIsFlutterProject = isFlutter;
    return isFlutter;
  }

  /// Test framework import: `flutter_test` for Flutter apps, `test` for pure
  /// Dart apps. `zfa setup --dart` only wires `test` (no
  /// `flutter_test`), so a pure-Dart app cannot resolve `flutter_test`.
  Directive _testFrameworkImport(bool isFlutter) => Directive.import(
    isFlutter
        ? 'package:flutter_test/flutter_test.dart'
        : 'package:test/test.dart',
  );

  /// Zuraffa core import: `zuraffa_flutter` (which re-exports `zuraffa`) for
  /// Flutter apps, plain `zuraffa` for pure-Dart apps. The params classes
  /// (UpdateParams, ListQueryParams, DeleteParams, QueryParams, ToggleParams,
  /// NoParams, Eq, Success, Failure) are all exported from
  /// `package:zuraffa/zuraffa.dart` (lib/zuraffa.dart → src/core/params/index.dart).
  /// A pure-Dart app cannot import `package:zuraffa_flutter/zuraffa_flutter.dart`
  /// (which transitively pulls in `flutter`).
  Directive _zuraffaCoreImport(bool isFlutter) => Directive.import(
    isFlutter
        ? 'package:zuraffa_flutter/zuraffa_flutter.dart'
        : 'package:zuraffa/zuraffa.dart',
  );
}

extension ExpressionClosure on Expression {
  Expression toClosure({bool asAsync = false}) {
    return Method(
      (m) => m
        ..body = code
        ..modifier = asAsync ? MethodModifier.async : null,
    ).closure;
  }
}

extension CodeClosure on Code {
  Expression toClosure({bool asAsync = false}) {
    return Method(
      (m) => m
        ..body = this
        ..modifier = asAsync ? MethodModifier.async : null,
    ).closure;
  }
}
