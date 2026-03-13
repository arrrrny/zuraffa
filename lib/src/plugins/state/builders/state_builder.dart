import 'package:code_builder/code_builder.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../core/constants/known_types.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

/// Generates state classes for presentation controllers.
///
/// Builds immutable state classes with flags, copyWith, and helpers based on
/// the configured entity methods.
///
/// Example:
/// ```dart
/// final builder = StateBuilder(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final file = await builder.generate(GeneratorConfig(name: 'Product'));
/// ```
class StateBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;

  /// Creates a [StateBuilder].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param options Generation flags for writing behavior and logging.
  /// @param specLibrary Optional spec library override.
  StateBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
  }) : specLibrary = specLibrary ?? const SpecLibrary();

  /// Generates a state file for the given [config].
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @returns Generated state file metadata.
  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final stateName = '${entityName}State';
    final fileName = '${entitySnake}_state.dart';
    final domainSnake = config.effectiveDomain;
    final statePathParts = <String>[
      outputDir,
      'presentation',
      'pages',
      domainSnake,
    ];
    final stateDirPath = path.joinAll(statePathParts);
    final filePath = path.join(stateDirPath, fileName);

    final needsEntityListField =
        !config.isCustomUseCase &&
        config.methods.any((m) => ['getList', 'watchList'].contains(m));
    final needsEntityField =
        !config.isCustomUseCase &&
        config.methods.any(
          (m) => ['get', 'watch', 'create', 'update', 'delete'].contains(m),
        );

    final imports = <String>['package:zuraffa/zuraffa.dart'];

    if (config.isCustomUseCase) {
      if (config.returnsType != null) {
        final types = config.returnsType!
            .replaceAll('List<', '')
            .replaceAll('>', '')
            .replaceAll('?', '');
        for (final type in types.split(',').map((t) => t.trim())) {
          if (!KnownTypes.isDartPrimitive(type)) {
            final snake = StringUtils.camelToSnake(type);
            imports.add('../../../domain/entities/$snake/$snake.dart');
          }
        }
      }
    } else if (needsEntityListField || needsEntityField) {
      final entityPath =
          '../../../domain/entities/$domainSnake/$domainSnake.dart';
      imports.add(entityPath);
    }

    final directives = imports.toSet().map(Directive.import).toList();

    final fields = <Field>[
      _docField(
        'The current error, if any',
        'error',
        _nullableType('AppFailure'),
      ),
    ];

    if (config.isCustomUseCase || (config.isOrchestrator && !config.generateUseCase)) {
      if (config.isOrchestrator && !config.generateUseCase) {
        for (final usecaseName in config.usecases) {
          final info = _parseUseCaseInfo(usecaseName, config);
          if (info.returnsType != null && info.returnsType != 'void') {
            final fieldName = '${info.fieldName}Data';
            fields.add(
              _docField(
                'The result data for ${info.className}',
                fieldName,
                _nullableType(info.returnsType!),
              ),
            );
          }
          fields.add(
            _docField(
              'Whether ${info.className} is in progress',
              'is${StringUtils.convertToPascalCase(info.fieldName)}Loading',
              refer('bool'),
            ),
          );
        }
      } else {
        fields.add(
          _docField(
            'Whether the operation is in progress',
            'isLoading',
            refer('bool'),
          ),
        );

        if (config.returnsType != null && config.returnsType != 'void') {
          final returnsType = config.returnsType!;
          final isNullable = returnsType.endsWith('?');
          final symbol = isNullable
              ? returnsType.substring(0, returnsType.length - 1)
              : returnsType;

          fields.add(
            _docField(
              'The result data',
              'data',
              TypeReference(
                (b) => b
                  ..symbol = symbol
                  ..isNullable = true,
              ),
            ),
          );
        }
      }

      final constructor = _buildCustomConstructor(config);
      final copyWith = _buildCustomCopyWith(stateName, config);
      final hasErrorGetter = _buildHasErrorGetter();
      final equality = _buildCustomEqualityOperator(stateName, config);
      final hashCodeGetter = _buildCustomHashCodeGetter(config);
      final toStringMethod = _buildCustomToString(stateName, config);

      final clazz = Class(
        (c) => c
          ..name = stateName
          ..fields.addAll(fields)
          ..constructors.add(constructor)
          ..methods.addAll([
            copyWith,
            hasErrorGetter,
            equality,
            hashCodeGetter,
            toStringMethod,
          ]),
      );

      final content = specLibrary.emitLibrary(
        specLibrary.library(specs: [clazz], directives: directives),
      );

      return FileUtils.writeFile(
        filePath,
        content,
        'state',
        force: options.force,
        dryRun: options.dryRun,
        verbose: options.verbose,
        revert: config.revert,
      );
    } else {
      if (needsEntityListField) {
        fields.add(
          _docField(
            'The list of $entityName entities',
            '${entityCamel}List',
            _listOf(entityName),
          ),
        );
      }

      if (needsEntityField) {
        fields.add(
          _docField(
            'The single $entityName entity',
            entityCamel,
            _nullableType(entityName),
          ),
        );
      }

      final boolFields = _boolFieldsForMethods(config.methods);
      fields.addAll(
        boolFields.map(
          (field) => _docField(field.doc, field.name, refer('bool')),
        ),
      );

      final constructor = _buildConstructor(
        entityName: entityName,
        entityCamel: entityCamel,
        needsEntityField: needsEntityField,
        needsEntityListField: needsEntityListField,
        boolFields: boolFields,
      );

      final copyWith = _buildCopyWith(
        stateName: stateName,
        entityName: entityName,
        entityCamel: entityCamel,
        needsEntityField: needsEntityField,
        needsEntityListField: needsEntityListField,
        boolFields: boolFields,
      );

      final isLoadingGetter = _buildIsLoadingGetter(boolFields);
      final hasErrorGetter = _buildHasErrorGetter();
      final equality = _buildEqualityOperator(
        stateName: stateName,
        entityCamel: entityCamel,
        needsEntityField: needsEntityField,
        needsEntityListField: needsEntityListField,
        boolFields: boolFields,
      );
      final hashCodeGetter = _buildHashCodeGetter(
        entityCamel: entityCamel,
        needsEntityField: needsEntityField,
        needsEntityListField: needsEntityListField,
        boolFields: boolFields,
      );
      final toStringMethod = _buildToString(
        stateName: stateName,
        entityCamel: entityCamel,
        needsEntityField: needsEntityField,
        needsEntityListField: needsEntityListField,
      );

      final clazz = Class(
        (c) => c
          ..name = stateName
          ..fields.addAll(fields)
          ..constructors.add(constructor)
          ..methods.addAll([
            copyWith,
            isLoadingGetter,
            hasErrorGetter,
            equality,
            hashCodeGetter,
            toStringMethod,
          ]),
      );

      final content = specLibrary.emitLibrary(
        specLibrary.library(specs: [clazz], directives: directives),
      );

      return FileUtils.writeFile(
        filePath,
        content,
        'state',
        force: options.force,
        dryRun: options.dryRun,
        verbose: options.verbose,
        revert: config.revert,
      );
    }
  }

  Constructor _buildCustomConstructor(GeneratorConfig config) {
    final params = <Parameter>[
      Parameter(
        (p) => p
          ..name = 'error'
          ..named = true
          ..toThis = true,
      ),
      Parameter(
        (p) => p
          ..name = 'isLoading'
          ..named = true
          ..toThis = true
          ..defaultTo = literalBool(false).code,
      ),
    ];

    if (config.returnsType != null && config.returnsType != 'void') {
      params.add(
        Parameter(
          (p) => p
            ..name = 'data'
            ..named = true
            ..toThis = true,
        ),
      );
    }

    return Constructor(
      (c) => c
        ..constant = true
        ..optionalParameters.addAll(params),
    );
  }

  Method _buildCustomCopyWith(String stateName, GeneratorConfig config) {
    final params = <Parameter>[
      Parameter(
        (p) => p
          ..name = 'error'
          ..named = true
          ..type = _nullableType('AppFailure'),
      ),
      Parameter(
        (p) => p
          ..name = 'isLoading'
          ..named = true
          ..type = refer('bool?'),
      ),
    ];

    final values = <String, Expression>{
      'error': refer('error').ifNullThen(_this('error')),
      'isLoading': refer('isLoading').ifNullThen(_this('isLoading')),
    };

    if (config.returnsType != null && config.returnsType != 'void') {
      final returnsType = config.returnsType!;
      final isNullable = returnsType.endsWith('?');
      final symbol = isNullable
          ? returnsType.substring(0, returnsType.length - 1)
          : returnsType;

      params.add(
        Parameter(
          (p) => p
            ..name = 'data'
            ..named = true
            ..type = TypeReference(
              (b) => b
                ..symbol = symbol
                ..isNullable = true,
            ),
        ),
      );
      values['data'] = refer('data').ifNullThen(_this('data'));
    }

    return Method(
      (m) => m
        ..name = 'copyWith'
        ..returns = refer(stateName)
        ..optionalParameters.addAll(params)
        ..lambda = true
        ..body = refer(stateName).call([], values).code,
    );
  }

  Method _buildHasErrorGetter() {
    return Method(
      (m) => m
        ..name = 'hasError'
        ..returns = refer('bool')
        ..type = MethodType.getter
        ..lambda = true
        ..body = refer('error').notEqualTo(refer('null')).code,
    );
  }

  Method _buildCustomEqualityOperator(String stateName, GeneratorConfig config) {
    final other = refer('other');
    final isIdentical = refer('identical').call([refer('this'), other]);
    final isType = other.isA(refer(stateName));

    final conditions = <Expression>[
      other.property('error').equalTo(refer('error')),
      other.property('isLoading').equalTo(refer('isLoading')),
    ];

    if (config.returnsType != null && config.returnsType != 'void') {
      conditions.add(other.property('data').equalTo(refer('data')));
    }

    final expression = conditions.reduce((a, b) => a.and(b));

    return Method(
      (m) => m
        ..name = 'operator =='
        ..returns = refer('bool')
        ..requiredParameters.add(Parameter((p) => p..name = 'other'..type = refer('Object')))
        ..annotations.add(refer('override'))
        ..lambda = true
        ..body = isIdentical.or(isType.and(expression)).code,
    );
  }

  Method _buildCustomHashCodeGetter(GeneratorConfig config) {
    final parts = <Expression>[
      _this('error').property('hashCode'),
      _this('isLoading').property('hashCode'),
    ];

    if (config.returnsType != null && config.returnsType != 'void') {
      parts.add(_this('data').property('hashCode'));
    }

    final expression = parts.reduce((a, b) => a.operatorAdd(b));

    return Method(
      (m) => m
        ..name = 'hashCode'
        ..returns = refer('int')
        ..type = MethodType.getter
        ..annotations.add(refer('override'))
        ..lambda = true
        ..body = expression.code,
    );
  }

  Method _buildCustomToString(String stateName, GeneratorConfig config) {
    final parts = <String>['error: \$error', 'isLoading: \$isLoading'];

    if (config.returnsType != null && config.returnsType != 'void') {
      parts.add('data: \$data');
    }

    return Method(
      (m) => m
        ..name = 'toString'
        ..returns = refer('String')
        ..annotations.add(refer('override'))
        ..lambda = true
        ..body = literalString('$stateName(${parts.join(', ')})').code,
    );
  }

  Field _docField(String doc, String name, Reference type) {
    return Field(
      (f) => f
        ..modifier = FieldModifier.final$
        ..type = type
        ..name = name
        ..docs.add('/// $doc'),
    );
  }

  Constructor _buildConstructor({
    required String entityName,
    required String entityCamel,
    required bool needsEntityField,
    required bool needsEntityListField,
    required List<_BoolField> boolFields,
  }) {
    final params = <Parameter>[
      Parameter(
        (p) => p
          ..name = 'error'
          ..named = true
          ..toThis = true,
      ),
    ];

    if (needsEntityListField) {
      params.add(
        Parameter(
          (p) => p
            ..name = '${entityCamel}List'
            ..named = true
            ..toThis = true
            ..defaultTo = literalConstList([], refer(entityName)).code,
        ),
      );
    }

    if (needsEntityField) {
      params.add(
        Parameter(
          (p) => p
            ..name = entityCamel
            ..named = true
            ..toThis = true,
        ),
      );
    }

    params.addAll(
      boolFields.map(
        (field) => Parameter(
          (p) => p
            ..name = field.name
            ..named = true
            ..toThis = true
            ..defaultTo = literalBool(false).code,
        ),
      ),
    );

    return Constructor(
      (c) => c
        ..constant = true
        ..optionalParameters.addAll(params),
    );
  }

  Method _buildCopyWith({
    required String stateName,
    required String entityName,
    required String entityCamel,
    required bool needsEntityField,
    required bool needsEntityListField,
    required List<_BoolField> boolFields,
  }) {
    final params = <Parameter>[
      Parameter(
        (p) => p
          ..name = 'error'
          ..named = true
          ..type = _nullableType('AppFailure'),
      ),
    ];

    final values = <String, Expression>{
      'error': refer('error').ifNullThen(_this('error')),
    };

    if (needsEntityListField) {
      params.add(
        Parameter(
          (p) => p
            ..name = '${entityCamel}List'
            ..named = true
            ..type = _nullableType('List<$entityName>'),
        ),
      );
      values['${entityCamel}List'] = refer('${entityCamel}List').ifNullThen(
        _this('${entityCamel}List'),
      );
    }

    if (needsEntityField) {
      params.add(
        Parameter(
          (p) => p
            ..name = entityCamel
            ..named = true
            ..type = _nullableType(entityName),
        ),
      );
      values[entityCamel] = refer(entityCamel).ifNullThen(_this(entityCamel));
    }

    for (final field in boolFields) {
      params.add(
        Parameter(
          (p) => p
            ..name = field.name
            ..named = true
            ..type = refer('bool?'),
        ),
      );
      values[field.name] = refer(field.name).ifNullThen(_this(field.name));
    }

    return Method(
      (m) => m
        ..name = 'copyWith'
        ..returns = refer(stateName)
        ..optionalParameters.addAll(params)
        ..lambda = true
        ..body = refer(stateName).call([], values).code,
    );
  }

  Method _buildIsLoadingGetter(List<_BoolField> boolFields) {
    Expression? expression;
    for (final field in boolFields) {
      final fieldRef = refer(field.name);
      if (expression == null) {
        expression = fieldRef;
      } else {
        expression = expression.or(fieldRef);
      }
    }

    return Method(
      (m) => m
        ..name = 'isLoading'
        ..returns = refer('bool')
        ..type = MethodType.getter
        ..lambda = true
        ..body = (expression ?? literalBool(false)).code,
    );
  }

  Method _buildEqualityOperator({
    required String stateName,
    required String entityCamel,
    required bool needsEntityField,
    required bool needsEntityListField,
    required List<_BoolField> boolFields,
  }) {
    final other = refer('other');
    final isIdentical = refer('identical').call([refer('this'), other]);
    final isType = other.isA(refer(stateName));

    final conditions = <Expression>[
      other.property('error').equalTo(refer('error')),
    ];

    if (needsEntityListField) {
      conditions.add(
        other.property('${entityCamel}List').equalTo(refer('${entityCamel}List')),
      );
    }

    if (needsEntityField) {
      conditions.add(other.property(entityCamel).equalTo(refer(entityCamel)));
    }

    for (final field in boolFields) {
      conditions.add(other.property(field.name).equalTo(refer(field.name)));
    }

    final expression = conditions.reduce((a, b) => a.and(b));

    return Method(
      (m) => m
        ..name = 'operator =='
        ..returns = refer('bool')
        ..requiredParameters.add(Parameter((p) => p..name = 'other'..type = refer('Object')))
        ..annotations.add(refer('override'))
        ..lambda = true
        ..body = isIdentical.or(isType.and(expression)).code,
    );
  }

  Method _buildHashCodeGetter({
    required String entityCamel,
    required bool needsEntityField,
    required bool needsEntityListField,
    required List<_BoolField> boolFields,
  }) {
    final parts = <Expression>[_this('error').property('hashCode')];

    if (needsEntityListField) {
      parts.add(_this('${entityCamel}List').property('hashCode'));
    }

    if (needsEntityField) {
      parts.add(_this(entityCamel).property('hashCode'));
    }

    for (final field in boolFields) {
      parts.add(_this(field.name).property('hashCode'));
    }

    final expression = parts.reduce((a, b) => a.operatorAdd(b));

    return Method(
      (m) => m
        ..name = 'hashCode'
        ..returns = refer('int')
        ..type = MethodType.getter
        ..annotations.add(refer('override'))
        ..lambda = true
        ..body = expression.code,
    );
  }

  Method _buildToString({
    required String stateName,
    required String entityCamel,
    required bool needsEntityField,
    required bool needsEntityListField,
  }) {
    final parts = <String>['error: \$error'];

    if (needsEntityListField) {
      parts.add('${entityCamel}List: \$${entityCamel}List');
    }

    if (needsEntityField) {
      parts.add('$entityCamel: \$$entityCamel');
    }

    return Method(
      (m) => m
        ..name = 'toString'
        ..returns = refer('String')
        ..annotations.add(refer('override'))
        ..lambda = true
        ..body = literalString('$stateName(${parts.join(', ')})').code,
    );
  }

  Reference _nullableType(String symbol) {
    return TypeReference((b) => b..symbol = symbol..isNullable = true);
  }

  Reference _listOf(String symbol) {
    return TypeReference((b) => b..symbol = 'List'..types.add(refer(symbol)));
  }

  Expression _this(String name) => refer('this').property(name);

  List<_BoolField> _boolFieldsForMethods(List<String> methods) {
    final fields = <_BoolField>[];
    for (final method in methods) {
      final name = StringUtils.convertToPascalCase(method);
      fields.add(_BoolField('is${name}Loading', 'Whether $method is loading'));
    }
    return fields;
  }

  String _findUseCaseDomain(String usecaseSnake, String defaultDomain) {
    final usecasesDir = Directory(path.join(outputDir, 'domain', 'usecases'));
    if (usecasesDir.existsSync()) {
      for (final dir in usecasesDir.listSync()) {
        if (dir is Directory) {
          final useCaseFile = File(
            path.join(dir.path, '${usecaseSnake}_usecase.dart'),
          );
          if (useCaseFile.existsSync()) {
            return path.basename(dir.path);
          }
        }
      }
    }
    // Try to find if it is an entity-based usecase
    final possiblePrefixes = ['get_', 'create_', 'update_', 'delete_', 'watch_'];
    for (final prefix in possiblePrefixes) {
      if (usecaseSnake.startsWith(prefix)) {
        final entitySnake = usecaseSnake.replaceFirst(prefix, '').replaceFirst('_list', '');
        return entitySnake;
      }
    }

    // Fallback to the default domain if not found
    return defaultDomain;
  }

  _UseCaseInfo _parseUseCaseInfo(String u, GeneratorConfig config) {
    final className = u.endsWith('UseCase') ? u : '${u}UseCase';
    final fieldName = StringUtils.pascalToCamel(
      className.replaceAll('UseCase', ''),
    );
    final usecaseSnake = StringUtils.camelToSnake(
      className.replaceAll('UseCase', ''),
    );

    // Try to find the file and parse params/returns
    String? paramsType;
    String? returnsType;
    String? useCaseType;

    final usecaseDomain = _findUseCaseDomain(usecaseSnake, config.effectiveDomain);
    final filePath = path.join(outputDir, 'domain', 'usecases', usecaseDomain, '${usecaseSnake}_usecase.dart');
    if (File(filePath).existsSync()) {
      final content = File(filePath).readAsStringSync();
      final extendsMatch = RegExp(r'extends (UseCase|StreamUseCase|CompletableUseCase|SyncUseCase)<([^>]+)>').firstMatch(content);
      if (extendsMatch != null) {
        useCaseType = extendsMatch.group(1)?.toLowerCase();
        final typesStr = extendsMatch.group(2);
        if (typesStr != null) {
          final types = typesStr.split(',').map((e) => e.trim()).toList();
          if (useCaseType == 'completableusecase') {
            useCaseType = 'completable';
            paramsType = types[0];
            returnsType = 'void';
          } else if (types.length >= 2) {
            returnsType = types[0];
            paramsType = types[1];
            if (useCaseType == 'streamusecase') useCaseType = 'stream';
            if (useCaseType == 'syncusecase') useCaseType = 'sync';
            if (useCaseType == 'usecase') useCaseType = 'future';
          }
        }
      }
    }

    return _UseCaseInfo(
      className: className,
      fieldName: fieldName,
      paramsType: paramsType,
      returnsType: returnsType,
      useCaseType: useCaseType,
    );
  }
}

class _BoolField {
  final String name;
  final String doc;
  _BoolField(this.name, this.doc);
}

class _UseCaseInfo {
  final String className;
  final String fieldName;
  final String? paramsType;
  final String? returnsType;
  final String? useCaseType;

  _UseCaseInfo({
    required this.className,
    required this.fieldName,
    this.paramsType,
    this.returnsType,
    this.useCaseType,
  });
}
