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
  /// returns a sensible default value for every declared instance member.
  ///
  /// Uses the analyzer to parse [filePath], find the first class declaration,
  /// and emit separate `@override` method/getter/setter stubs whose bodies return:
  /// - `Future.value(<default>)` for async methods
  /// - `Stream.value(<default>)` for stream methods
  /// - `<default>` for synchronous methods
  /// - empty body for void methods
  /// - `UnimplementedError` when no non-null typed default is available
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
    final baseInterfaceName = interfaceName.split('<').first.trim();
    for (final node in unit.declarations) {
      if (node is ast.ClassDeclaration &&
          (node.namePart.typeName.lexeme == baseInterfaceName ||
              node.namePart.typeName.lexeme == '\$$baseInterfaceName')) {
        targetClass = node;
        break;
      }
    }
    if (targetClass == null) return null;

    final methods = <Method>[];
    for (final member in targetClass.body.members) {
      if (member is ast.MethodDeclaration && !member.isStatic) {
        methods.add(_generateFakeMethod(member, entityTypes));
      } else if (member is ast.FieldDeclaration && !member.isStatic) {
        methods.addAll(_generateFakeFieldAccessors(member, entityTypes));
      }
    }

    return Class(
      (c) => c
        ..name = className
        ..implements.add(refer(interfaceName))
        ..methods.addAll(methods),
    );
  }

  /// Returns a parsed dependency fake or fails before invalid Dart is emitted.
  Future<Class> _requireFakeClassForDependency({
    required String className,
    required String interfaceName,
    required String? filePath,
    required String packageName,
    required String projectRoot,
    required Set<String> entityTypes,
  }) async {
    if (filePath == null) {
      throw StateError(
        'Cannot generate $className: source for $interfaceName was not found.',
      );
    }

    final fakeClass = await _generateFakeClassForDependency(
      className: className,
      interfaceName: interfaceName,
      filePath: filePath,
      packageName: packageName,
      projectRoot: projectRoot,
      entityTypes: entityTypes,
    );
    if (fakeClass == null) {
      throw StateError(
        'Cannot generate $className: $interfaceName was not declared in '
        '$filePath.',
      );
    }
    return fakeClass;
  }

  /// Generates one concrete override for a declared interface member.
  Method _generateFakeMethod(
    ast.MethodDeclaration method,
    Set<String> entityTypes,
  ) {
    final name = method.name.lexeme;
    if (method.isOperator) {
      throw StateError(
        'Cannot generate a fake for operator ${method.name.lexeme}; '
        'operator members are not representable by code_builder.Method.',
      );
    }

    final returnType = method.returnType?.toSource() ?? 'dynamic';
    final defaultValue = method.isSetter || returnType == 'void'
        ? ''
        : _defaultValueForType(returnType, entityTypes);

    return Method((builder) {
      builder
        ..name = name
        ..annotations.add(refer('override'))
        ..body = _fakeMemberBody(name, defaultValue);

      if (method.isGetter) {
        builder
          ..type = MethodType.getter
          ..returns = refer(returnType);
      } else if (method.isSetter) {
        builder.type = MethodType.setter;
      } else {
        builder.returns = refer(returnType);
      }

      for (final typeParameter
          in method.typeParameters?.typeParameters ?? const []) {
        builder.types.add(refer(typeParameter.toSource()));
      }

      for (final parameter in method.parameters?.parameters ?? const []) {
        final generated = _parameterFromAst(parameter);
        if (parameter.isNamed || parameter.isOptionalPositional) {
          builder.optionalParameters.add(generated);
        } else {
          builder.requiredParameters.add(generated);
        }
      }
    });
  }

  List<Method> _generateFakeFieldAccessors(
    ast.FieldDeclaration field,
    Set<String> entityTypes,
  ) {
    final type = field.fields.type?.toSource() ?? 'dynamic';
    final defaultValue = _defaultValueForType(type, entityTypes);
    final methods = <Method>[];

    for (final variable in field.fields.variables) {
      final name = variable.name.lexeme;
      methods.add(
        Method(
          (builder) => builder
            ..name = name
            ..type = MethodType.getter
            ..returns = refer(type)
            ..annotations.add(refer('override'))
            ..body = _fakeMemberBody(name, defaultValue),
        ),
      );
      if (!field.fields.isFinal && !field.fields.isConst) {
        methods.add(
          Method(
            (builder) => builder
              ..name = name
              ..type = MethodType.setter
              ..annotations.add(refer('override'))
              ..requiredParameters.add(
                Parameter(
                  (parameter) => parameter
                    ..name = 'value'
                    ..type = refer(type),
                ),
              )
              ..body = const Code(''),
          ),
        );
      }
    }
    return methods;
  }

  Parameter _parameterFromAst(ast.FormalParameter parameter) {
    var declaration = parameter.toSource();
    final defaultClause = parameter.defaultClause;
    if (defaultClause != null) {
      final separatorOffset = defaultClause.separator.offset - parameter.offset;
      declaration = declaration.substring(0, separatorOffset).trimRight();
    }

    return Parameter((builder) {
      builder
        ..name = declaration
        ..named = parameter.isNamed;
      if (defaultClause != null) {
        builder.defaultTo = Code(defaultClause.value.toSource());
      }
    });
  }

  Code _fakeMemberBody(String memberName, String? defaultValue) {
    if (defaultValue == '') return const Code('');
    if (defaultValue == null) {
      return Code(
        "throw UnimplementedError('No typed fake value for $memberName');",
      );
    }
    return Code('return $defaultValue;');
  }

  /// Determines the raw Dart expression string for a default value of
  /// [returnType] — handles `Future<T>`, `Stream<T>`, nullable types,
  /// collection types, entity types, and built-in primitives.
  String? _defaultValueForType(String returnType, Set<String> entityTypes) {
    // Future<T> → Future.value(<innerDefault>)
    if (returnType.startsWith('Future<') && returnType.endsWith('>')) {
      final inner = _extractInnerType(returnType);
      final innerDefault = _defaultValueForType(inner, entityTypes);
      if (innerDefault == null) return null;
      return innerDefault.isEmpty
          ? 'Future.value()'
          : 'Future.value($innerDefault)';
    }
    // Stream<T> → Stream.value(<innerDefault>)
    if (returnType.startsWith('Stream<') && returnType.endsWith('>')) {
      final inner = _extractInnerType(returnType);
      final innerDefault = _defaultValueForType(inner, entityTypes);
      if (innerDefault == null) return null;
      return innerDefault.isEmpty
          ? 'Stream.empty()'
          : 'Stream.value($innerDefault)';
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
      'num' => '0',
      'double' => '0.0',
      'bool' => 'false',
      'dynamic' => 'null',
      'Object' => 'Object()',
      'void' => '',
      _ => null,
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
      _ => refer('t${type.split('<').first.trim()}'),
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

  /// Zuraffa core import for generated tests. Every generated test wires a
  /// zuraffa-native mock (MockDataSource / ThrowingDataSource), so it imports
  /// the canonical `package:zuraffa/mock.dart` marker. That library re-exports
  /// the full zuraffa core surface (Loggable, FailureHandler, Result, the
  /// params family, etc.) plus the `zuraffaMockLibrary` constant, so static
  /// tooling (e.g. speckit-tdd-setup) can detect zuraffa-native mocking without
  /// a third-party double library. Works for both Flutter and pure-Dart apps
  /// because `zuraffa` is always resolvable in a zuraffa app.
  Directive _zuraffaCoreImport(bool isFlutter) => Directive.import(
    'package:zuraffa/mock.dart',
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
