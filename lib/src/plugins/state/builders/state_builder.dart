import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/builder/patterns/common_patterns.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';

import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

/// Generates state classes for presentation controllers.
class StateBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final FileSystem fileSystem;

  StateBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    FileSystem? fileSystem,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       fileSystem = fileSystem ?? FileSystem.create();

  /// Generates a state file for the given [config].
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
        !config.noEntity &&
        config.methods.any((m) => ['getList', 'watchList'].contains(m));
    final needsEntityField =
        (!config.noEntity && (config.generateVpcs || config.generateState)) ||
        (!config.noEntity &&
            config.methods.any(
              (m) => [
                'get',
                'watch',
                'create',
                'update',
                'toggle',
                'delete',
              ].contains(m),
            ));

    final imports = <String>['package:zuraffa/zuraffa.dart'];

    if (config.isCustomUseCase || config.isOrchestrator) {
      final types = <String>[if (!config.noEntity) config.name];
      if (config.returnsType != null) {
        types.addAll(CommonPatterns.extractBaseTypes(config.returnsType!));
      }
      if (config.isOrchestrator) {
        for (final usecaseName in config.usecases) {
          final info = await CommonPatterns.parseUseCaseInfo(
            usecaseName,
            config,
            outputDir,
            fileSystem: fileSystem,
          );
          if (info.returnsType != null) {
            types.addAll(CommonPatterns.extractBaseTypes(info.returnsType!));
          }
        }
      }

      final entityImports = CommonPatterns.entityImports(
        types,
        config,
        depth: 3,
        fileSystem: fileSystem,
      );
      imports.addAll(entityImports);
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

    if (needsEntityField) {
      fields.add(
        _docField(
          'The single $entityName entity',
          entityCamel,
          _nullableType(entityName),
        ),
      );
    }

    if (needsEntityListField) {
      fields.add(
        _docField(
          'The list of $entityName entities',
          '${entityCamel}List',
          _listOf(entityName),
        ),
      );
      fields.add(
        _docField('The current offset for pagination', 'offset', refer('int')),
      );
      fields.add(
        _docField(
          'The maximum number of items to fetch',
          'limit',
          refer('int'),
        ),
      );
      fields.add(
        _docField(
          'Whether more items are available to fetch',
          'hasMore',
          refer('bool'),
        ),
      );
    }

    if (config.isCustomUseCase || config.isOrchestrator) {
      final orchestratorBoolFields = <_BoolField>[];
      if (config.isOrchestrator) {
        for (final usecaseName in config.usecases) {
          final info = await CommonPatterns.parseUseCaseInfo(
            usecaseName,
            config,
            outputDir,
            fileSystem: fileSystem,
          );
          final loadingName =
              'is${StringUtils.capitalize(info.fieldName)}Loading';

          orchestratorBoolFields.add(
            _BoolField(loadingName, 'Whether ${info.className} is in progress'),
          );

          final returns =
              info.returnsType ??
              (config.usecases.length == 1 ? config.returnsType : null);
          if (returns != null && returns != 'void') {
            final fieldName = '${info.fieldName}Response';
            fields.add(
              _docField(
                'The result data for ${info.className}',
                fieldName,
                _nullableType(returns),
              ),
            );
          }
          fields.add(
            _docField(
              'Whether ${info.className} is in progress',
              loadingName,
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

      final constructor = await _buildCustomConstructor(config);
      final copyWith = await _buildCustomCopyWith(stateName, config);
      final hasErrorGetter = _buildHasErrorGetter();
      final equality = await _buildCustomEqualityOperator(stateName, config);
      final hashCodeGetter = await _buildCustomHashCodeGetter(config);
      final toStringMethod = await _buildCustomToString(stateName, config);

      final methods = [
        copyWith,
        hasErrorGetter,
        equality,
        hashCodeGetter,
        toStringMethod,
      ];

      if (config.isOrchestrator) {
        methods.insert(1, _buildIsLoadingGetter(orchestratorBoolFields));
      }

      final clazz = Class(
        (c) => c
          ..name = stateName
          ..fields.addAll(fields)
          ..constructors.add(constructor)
          ..methods.addAll(methods),
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
        fileSystem: fileSystem,
      );
    } else {
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
        fileSystem: fileSystem,
      );
    }
  }

  Future<Constructor> _buildCustomConstructor(GeneratorConfig config) async {
    final entityCamel = config.nameCamel;
    final needsEntityListField =
        !config.noEntity &&
        config.methods.any((m) => ['getList', 'watchList'].contains(m));
    final needsEntityField =
        (!config.noEntity && (config.generateVpcs || config.generateState)) ||
        (!config.noEntity &&
            config.methods.any(
              (m) => [
                'get',
                'watch',
                'create',
                'update',
                'toggle',
                'delete',
              ].contains(m),
            ));

    final params = <Parameter>[
      Parameter(
        (p) => p
          ..name = 'error'
          ..named = true
          ..toThis = true,
      ),
    ];

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

    if (needsEntityListField) {
      params.addAll([
        Parameter(
          (p) => p
            ..name = '${entityCamel}List'
            ..named = true
            ..toThis = true
            ..defaultTo = literalList([]).code,
        ),
        Parameter(
          (p) => p
            ..name = 'offset'
            ..named = true
            ..toThis = true
            ..defaultTo = literalNum(0).code,
        ),
        Parameter(
          (p) => p
            ..name = 'limit'
            ..named = true
            ..toThis = true
            ..defaultTo = literalNum(20).code,
        ),
        Parameter(
          (p) => p
            ..name = 'hasMore'
            ..named = true
            ..toThis = true
            ..defaultTo = literalBool(true).code,
        ),
      ]);
    }

    if (!config.isOrchestrator) {
      params.add(
        Parameter(
          (p) => p
            ..name = 'isLoading'
            ..named = true
            ..toThis = true
            ..defaultTo = literalBool(false).code,
        ),
      );
    }

    if (config.isOrchestrator) {
      for (final usecaseName in config.usecases) {
        final info = await CommonPatterns.parseUseCaseInfo(
          usecaseName,
          config,
          outputDir,
          fileSystem: fileSystem,
        );
        final returns =
            info.returnsType ??
            (config.usecases.length == 1 ? config.returnsType : null);
        if (returns != null && returns != 'void') {
          params.add(
            Parameter(
              (p) => p
                ..name = '${info.fieldName}Response'
                ..named = true
                ..toThis = true,
            ),
          );
        }
        params.add(
          Parameter(
            (p) => p
              ..name = 'is${StringUtils.capitalize(info.fieldName)}Loading'
              ..named = true
              ..toThis = true
              ..defaultTo = literalBool(false).code,
          ),
        );
      }
    }

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

  Future<Method> _buildCustomCopyWith(
    String stateName,
    GeneratorConfig config,
  ) async {
    final entityName = config.name;
    final entityCamel = config.nameCamel;
    final needsEntityListField =
        !config.noEntity &&
        config.methods.any((m) => ['getList', 'watchList'].contains(m));
    final needsEntityField =
        (!config.noEntity && (config.generateVpcs || config.generateState)) ||
        (!config.noEntity &&
            config.methods.any(
              (m) => [
                'get',
                'watch',
                'create',
                'update',
                'toggle',
                'delete',
              ].contains(m),
            ));

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

    if (needsEntityField) {
      params.add(
        Parameter(
          (p) => p
            ..name = entityCamel
            ..named = true
            ..type = refer('$entityName?'),
        ),
      );
      values[entityCamel] = refer(entityCamel).ifNullThen(_this(entityCamel));
    }

    if (needsEntityListField) {
      params.addAll([
        Parameter(
          (p) => p
            ..name = '${entityCamel}List'
            ..named = true
            ..type = refer('List<$entityName>?'),
        ),
        Parameter(
          (p) => p
            ..name = 'offset'
            ..named = true
            ..type = refer('int?'),
        ),
        Parameter(
          (p) => p
            ..name = 'limit'
            ..named = true
            ..type = refer('int?'),
        ),
        Parameter(
          (p) => p
            ..name = 'hasMore'
            ..named = true
            ..type = refer('bool?'),
        ),
      ]);
      values['${entityCamel}List'] = refer(
        '${entityCamel}List',
      ).ifNullThen(_this('${entityCamel}List'));
      values['offset'] = refer('offset').ifNullThen(_this('offset'));
      values['limit'] = refer('limit').ifNullThen(_this('limit'));
      values['hasMore'] = refer('hasMore').ifNullThen(_this('hasMore'));
    }

    if (!config.isOrchestrator) {
      params.add(
        Parameter(
          (p) => p
            ..name = 'isLoading'
            ..named = true
            ..type = refer('bool?'),
        ),
      );
      values['isLoading'] = refer('isLoading').ifNullThen(_this('isLoading'));
    }

    if (config.isOrchestrator) {
      for (final usecaseName in config.usecases) {
        final info = await CommonPatterns.parseUseCaseInfo(
          usecaseName,
          config,
          outputDir,
          fileSystem: fileSystem,
        );
        final loadingName =
            'is${StringUtils.capitalize(info.fieldName)}Loading';
        params.add(
          Parameter(
            (p) => p
              ..name = loadingName
              ..named = true
              ..type = refer('bool?'),
          ),
        );
        values[loadingName] = refer(loadingName).ifNullThen(_this(loadingName));

        final returns =
            info.returnsType ??
            (config.usecases.length == 1 ? config.returnsType : null);
        if (returns != null && returns != 'void') {
          final fieldName = '${info.fieldName}Response';
          params.add(
            Parameter(
              (p) => p
                ..name = fieldName
                ..named = true
                ..type = _nullableType(returns),
            ),
          );
          values[fieldName] = refer(fieldName).ifNullThen(_this(fieldName));
        }
      }
    }

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

  Future<Method> _buildCustomEqualityOperator(
    String stateName,
    GeneratorConfig config,
  ) async {
    final other = refer('other');
    final isIdentical = refer('identical').call([refer('this'), other]);
    final isType = other.isA(refer(stateName));

    final entityCamel = config.nameCamel;
    final needsEntityListField =
        !config.noEntity &&
        config.methods.any((m) => ['getList', 'watchList'].contains(m));
    final needsEntityField =
        (!config.noEntity && (config.generateVpcs || config.generateState)) ||
        (!config.noEntity &&
            config.methods.any(
              (m) => [
                'get',
                'watch',
                'create',
                'update',
                'toggle',
                'delete',
              ].contains(m),
            ));

    final conditions = <Expression>[
      other.property('error').equalTo(refer('error')),
    ];

    if (needsEntityField) {
      conditions.add(other.property(entityCamel).equalTo(refer(entityCamel)));
    }

    if (needsEntityListField) {
      conditions.add(
        other
            .property('${entityCamel}List')
            .equalTo(refer('${entityCamel}List')),
      );
      conditions.add(other.property('offset').equalTo(refer('offset')));
      conditions.add(other.property('limit').equalTo(refer('limit')));
      conditions.add(other.property('hasMore').equalTo(refer('hasMore')));
    }

    if (!config.isOrchestrator) {
      conditions.add(other.property('isLoading').equalTo(refer('isLoading')));
    }

    if (config.isOrchestrator) {
      for (final usecaseName in config.usecases) {
        final info = await CommonPatterns.parseUseCaseInfo(
          usecaseName,
          config,
          outputDir,
          fileSystem: fileSystem,
        );
        final fieldName = '${info.fieldName}Response';
        final loadingName =
            'is${StringUtils.capitalize(info.fieldName)}Loading';

        final returns =
            info.returnsType ??
            (config.usecases.length == 1 ? config.returnsType : null);
        if (returns != null && returns != 'void') {
          conditions.add(other.property(fieldName).equalTo(refer(fieldName)));
        }
        conditions.add(other.property(loadingName).equalTo(refer(loadingName)));
      }
    }

    if (config.returnsType != null && config.returnsType != 'void') {
      conditions.add(other.property('data').equalTo(refer('data')));
    }

    final expression = conditions.reduce((a, b) => a.and(b));

    return Method(
      (m) => m
        ..name = 'operator =='
        ..returns = refer('bool')
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'other'
              ..type = refer('Object'),
          ),
        )
        ..annotations.add(refer('override'))
        ..lambda = true
        ..body = isIdentical.or(isType.and(expression)).code,
    );
  }

  Future<Method> _buildCustomHashCodeGetter(GeneratorConfig config) async {
    final entityCamel = config.nameCamel;
    final needsEntityListField =
        !config.noEntity &&
        config.methods.any((m) => ['getList', 'watchList'].contains(m));
    final needsEntityField =
        (!config.noEntity && (config.generateVpcs || config.generateState)) ||
        (!config.noEntity &&
            config.methods.any(
              (m) => [
                'get',
                'watch',
                'create',
                'update',
                'toggle',
                'delete',
              ].contains(m),
            ));

    final parts = <Expression>[refer('error').property('hashCode')];

    if (needsEntityField) {
      parts.add(refer(entityCamel).property('hashCode'));
    }

    if (needsEntityListField) {
      parts.add(refer('${entityCamel}List').property('hashCode'));
      parts.add(refer('offset').property('hashCode'));
      parts.add(refer('limit').property('hashCode'));
      parts.add(refer('hasMore').property('hashCode'));
    }

    if (!config.isOrchestrator) {
      parts.add(refer('isLoading').property('hashCode'));
    }

    if (config.isOrchestrator) {
      for (final usecaseName in config.usecases) {
        final info = await CommonPatterns.parseUseCaseInfo(
          usecaseName,
          config,
          outputDir,
          fileSystem: fileSystem,
        );
        final returns =
            info.returnsType ??
            (config.usecases.length == 1 ? config.returnsType : null);
        final fieldName = '${info.fieldName}Response';
        final loadingName =
            'is${StringUtils.capitalize(info.fieldName)}Loading';

        if (returns != null && returns != 'void') {
          parts.add(refer(fieldName).property('hashCode'));
        }
        parts.add(refer(loadingName).property('hashCode'));
      }
    }

    if (config.returnsType != null && config.returnsType != 'void') {
      parts.add(refer('data').property('hashCode'));
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

  Future<Method> _buildCustomToString(
    String stateName,
    GeneratorConfig config,
  ) async {
    final entityCamel = config.nameCamel;
    final needsEntityListField =
        !config.noEntity &&
        config.methods.any((m) => ['getList', 'watchList'].contains(m));
    final needsEntityField =
        (!config.noEntity && (config.generateVpcs || config.generateState)) ||
        (!config.noEntity &&
            config.methods.any(
              (m) => [
                'get',
                'watch',
                'create',
                'update',
                'toggle',
                'delete',
              ].contains(m),
            ));

    final parts = <String>['error: \$error'];

    if (needsEntityField) {
      parts.add('$entityCamel: \$$entityCamel');
    }

    if (needsEntityListField) {
      parts.add('${entityCamel}List: \$${entityCamel}List');
      parts.add('offset: \$offset');
      parts.add('limit: \$limit');
      parts.add('hasMore: \$hasMore');
    }

    if (!config.isOrchestrator) {
      parts.add('isLoading: \$isLoading');
    }

    if (config.isOrchestrator) {
      for (final usecaseName in config.usecases) {
        final info = await CommonPatterns.parseUseCaseInfo(
          usecaseName,
          config,
          outputDir,
          fileSystem: fileSystem,
        );
        final returns =
            info.returnsType ??
            (config.usecases.length == 1 ? config.returnsType : null);
        final fieldName = '${info.fieldName}Response';
        final loadingName =
            'is${StringUtils.capitalize(info.fieldName)}Loading';

        if (returns != null && returns != 'void') {
          parts.add('$fieldName: \$$fieldName');
        }
        parts.add('$loadingName: \$$loadingName');
      }
    }

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
      params.add(
        Parameter(
          (p) => p
            ..name = 'offset'
            ..named = true
            ..toThis = true
            ..defaultTo = literalNum(0).code,
        ),
      );
      params.add(
        Parameter(
          (p) => p
            ..name = 'limit'
            ..named = true
            ..toThis = true
            ..defaultTo = literalNum(10).code,
        ),
      );
      params.add(
        Parameter(
          (p) => p
            ..name = 'hasMore'
            ..named = true
            ..toThis = true
            ..defaultTo = literalBool(true).code,
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
      values['${entityCamel}List'] = refer(
        '${entityCamel}List',
      ).ifNullThen(_this('${entityCamel}List'));
      params.add(
        Parameter(
          (p) => p
            ..name = 'offset'
            ..named = true
            ..type = refer('int?'),
        ),
      );
      values['offset'] = refer('offset').ifNullThen(_this('offset'));
      params.add(
        Parameter(
          (p) => p
            ..name = 'limit'
            ..named = true
            ..type = refer('int?'),
        ),
      );
      values['limit'] = refer('limit').ifNullThen(_this('limit'));
      params.add(
        Parameter(
          (p) => p
            ..name = 'hasMore'
            ..named = true
            ..type = refer('bool?'),
        ),
      );
      values['hasMore'] = refer('hasMore').ifNullThen(_this('hasMore'));
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
        other
            .property('${entityCamel}List')
            .equalTo(refer('${entityCamel}List')),
      );
      conditions.add(other.property('offset').equalTo(refer('offset')));
      conditions.add(other.property('limit').equalTo(refer('limit')));
      conditions.add(other.property('hasMore').equalTo(refer('hasMore')));
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
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'other'
              ..type = refer('Object'),
          ),
        )
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
    final parts = <Expression>[refer('error').property('hashCode')];

    if (needsEntityListField) {
      parts.add(refer('${entityCamel}List').property('hashCode'));
      parts.add(refer('offset').property('hashCode'));
      parts.add(refer('limit').property('hashCode'));
      parts.add(refer('hasMore').property('hashCode'));
    }

    if (needsEntityField) {
      parts.add(refer(entityCamel).property('hashCode'));
    }

    for (final field in boolFields) {
      parts.add(refer(field.name).property('hashCode'));
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
      parts.add('offset: \$offset');
      parts.add('limit: \$limit');
      parts.add('hasMore: \$hasMore');
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
    final cleanSymbol = symbol.endsWith('?')
        ? symbol.substring(0, symbol.length - 1)
        : symbol;
    return TypeReference(
      (b) => b
        ..symbol = cleanSymbol
        ..isNullable = true,
    );
  }

  Reference _listOf(String symbol) {
    return TypeReference(
      (b) => b
        ..symbol = 'List'
        ..types.add(refer(symbol)),
    );
  }

  Expression _this(String name) => refer('this').property(name);

  List<_BoolField> _boolFieldsForMethods(List<String> methods) {
    final fields = <_BoolField>[];
    for (final method in methods) {
      final continuous = StringUtils.toContinuous(method);
      fields.add(_BoolField('is$continuous', 'Whether $method is in progress'));
    }
    return fields;
  }
}

class _BoolField {
  final String name;
  final String doc;
  _BoolField(this.name, this.doc);
}
