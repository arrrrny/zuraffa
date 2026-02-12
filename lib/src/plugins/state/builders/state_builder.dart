import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';

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
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;

  /// Creates a [StateBuilder].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param options Generation flags for writing behavior and logging.
  /// @param dryRun Deprecated: use [options].
  /// @param force Deprecated: use [options].
  /// @param verbose Deprecated: use [options].
  /// @param specLibrary Optional spec library override.
  StateBuilder({
    required this.outputDir,
    GeneratorOptions options = const GeneratorOptions(),
    @Deprecated('Use options.dryRun') bool? dryRun,
    @Deprecated('Use options.force') bool? force,
    @Deprecated('Use options.verbose') bool? verbose,
    SpecLibrary? specLibrary,
  })  : options = options.copyWith(
          dryRun: dryRun ?? options.dryRun,
          force: force ?? options.force,
          verbose: verbose ?? options.verbose,
        ),
        dryRun = dryRun ?? options.dryRun,
        force = force ?? options.force,
        verbose = verbose ?? options.verbose,
        specLibrary = specLibrary ?? const SpecLibrary();

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
    final statePathParts = <String>[outputDir, 'presentation', 'pages'];
    statePathParts.add(entitySnake);
    final stateDirPath = path.joinAll(statePathParts);
    final filePath = path.join(stateDirPath, fileName);

    final needsEntityListField = config.methods.any(
      (m) => ['getList', 'watchList'].contains(m),
    );
    final needsEntityField = config.methods.any(
      (m) => ['get', 'watch', 'create', 'update', 'delete'].contains(m),
    );

    final imports = <String>['package:zuraffa/zuraffa.dart'];
    if (needsEntityListField || needsEntityField) {
      final entityPath =
          '../../../domain/entities/$entitySnake/$entitySnake.dart';
      imports.add(entityPath);
    }

    final directives = imports.map(Directive.import).toList();

    final fields = <Field>[
      _docField(
        'The current error, if any',
        'error',
        _nullableType('AppFailure'),
      ),
    ];

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
      force: force,
      dryRun: dryRun,
      verbose: verbose,
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
          ..type = _nullableType('AppFailure')
          ..named = true,
      ),
      Parameter(
        (p) => p
          ..name = 'clearError'
          ..type = refer('bool')
          ..named = true
          ..defaultTo = literalBool(false).code,
      ),
    ];

    if (needsEntityListField) {
      params.add(
        Parameter(
          (p) => p
            ..name = '${entityCamel}List'
            ..type = _nullableListOf(entityName)
            ..named = true,
        ),
      );
    }

    if (needsEntityField) {
      params.add(
        Parameter(
          (p) => p
            ..name = entityCamel
            ..type = _nullableType(entityName)
            ..named = true,
        ),
      );
    }

    params.addAll(
      boolFields.map(
        (field) => Parameter(
          (p) => p
            ..name = field.name
            ..type = _nullableType('bool')
            ..named = true,
        ),
      ),
    );

    final namedArgs = <String, Expression>{
      'error': refer(
        'clearError',
      ).conditional(literalNull, refer('error').ifNullThen(_this('error'))),
    };

    if (needsEntityListField) {
      namedArgs['${entityCamel}List'] = refer(
        '${entityCamel}List',
      ).ifNullThen(_this('${entityCamel}List'));
    }

    if (needsEntityField) {
      namedArgs[entityCamel] = refer(
        entityCamel,
      ).ifNullThen(_this(entityCamel));
    }

    for (final field in boolFields) {
      namedArgs[field.name] = refer(field.name).ifNullThen(_this(field.name));
    }

    final ctorCall = refer(stateName).call(const [], namedArgs);

    return Method(
      (m) => m
        ..name = 'copyWith'
        ..returns = refer(stateName)
        ..optionalParameters.addAll(params)
        ..body = Block((b) => b..statements.add(ctorCall.returned.statement)),
    );
  }

  Method _buildIsLoadingGetter(List<_BoolField> boolFields) {
    Expression expression;
    if (boolFields.isEmpty) {
      expression = literalBool(false);
    } else {
      expression = refer(boolFields.first.name);
      for (final field in boolFields.skip(1)) {
        expression = expression.or(refer(field.name));
      }
    }

    return Method(
      (m) => m
        ..name = 'isLoading'
        ..type = MethodType.getter
        ..returns = refer('bool')
        ..docs.add('/// Whether any operation is currently loading')
        ..body = Block((b) => b..statements.add(expression.returned.statement)),
    );
  }

  Method _buildHasErrorGetter() {
    final expression = refer('error').notEqualTo(literalNull);
    return Method(
      (m) => m
        ..name = 'hasError'
        ..type = MethodType.getter
        ..returns = refer('bool')
        ..docs.add('/// Whether there is an error to display')
        ..body = Block((b) => b..statements.add(expression.returned.statement)),
    );
  }

  Method _buildEqualityOperator({
    required String stateName,
    required String entityCamel,
    required bool needsEntityField,
    required bool needsEntityListField,
    required List<_BoolField> boolFields,
  }) {
    Expression rhs = refer('other')
        .isA(refer(stateName))
        .and(
          refer('runtimeType').equalTo(refer('other').property('runtimeType')),
        );

    if (needsEntityListField) {
      rhs = rhs.and(
        refer(
          '${entityCamel}List',
        ).equalTo(refer('other').property('${entityCamel}List')),
      );
    }
    if (needsEntityField) {
      rhs = rhs.and(
        refer(entityCamel).equalTo(refer('other').property(entityCamel)),
      );
    }

    rhs = rhs.and(refer('error').equalTo(refer('other').property('error')));

    for (final field in boolFields) {
      rhs = rhs.and(
        refer(field.name).equalTo(refer('other').property(field.name)),
      );
    }

    final expression = refer(
      'identical',
    ).call([refer('this'), refer('other')]).or(rhs);

    return Method(
      (m) => m
        ..name = 'operator =='
        ..annotations.add(refer('override'))
        ..returns = refer('bool')
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'other'
              ..type = refer('Object'),
          ),
        )
        ..body = Block((b) => b..statements.add(expression.returned.statement)),
    );
  }

  Method _buildHashCodeGetter({
    required String entityCamel,
    required bool needsEntityField,
    required bool needsEntityListField,
    required List<_BoolField> boolFields,
  }) {
    final parts = <Expression>[];
    if (needsEntityListField) {
      parts.add(refer('${entityCamel}List').property('hashCode'));
    }
    if (needsEntityField) {
      parts.add(refer(entityCamel).property('hashCode'));
    }
    parts.add(refer('error').property('hashCode'));
    parts.addAll(
      boolFields.map((field) => refer(field.name).property('hashCode')),
    );

    Expression expression;
    if (parts.isEmpty) {
      expression = literalNum(0);
    } else {
      expression = parts.first;
      for (final part in parts.skip(1)) {
        expression = expression.operatorBitwiseXor(part);
      }
    }

    return Method(
      (m) => m
        ..name = 'hashCode'
        ..type = MethodType.getter
        ..annotations.add(refer('override'))
        ..returns = refer('int')
        ..body = Block((b) => b..statements.add(expression.returned.statement)),
    );
  }

  Method _buildToString({
    required String stateName,
    required String entityCamel,
    required bool needsEntityField,
    required bool needsEntityListField,
  }) {
    String value;
    if (needsEntityListField && needsEntityField) {
      value =
          '$stateName(${entityCamel}List: \${${entityCamel}List.length}, $entityCamel: \$$entityCamel, isLoading: \$isLoading, error: \$error)';
    } else if (needsEntityListField) {
      value =
          '$stateName(${entityCamel}List: \${${entityCamel}List.length}, isLoading: \$isLoading, error: \$error)';
    } else if (needsEntityField) {
      value =
          '$stateName($entityCamel: \$$entityCamel, isLoading: \$isLoading, error: \$error)';
    } else {
      value = '$stateName(isLoading: \$isLoading, error: \$error)';
    }

    final expression = literalString(value);

    return Method(
      (m) => m
        ..name = 'toString'
        ..returns = refer('String')
        ..annotations.add(refer('override'))
        ..body = Block((b) => b..statements.add(expression.returned.statement)),
    );
  }

  Reference _listOf(String entityName) {
    return TypeReference(
      (b) => b
        ..symbol = 'List'
        ..types.add(refer(entityName)),
    );
  }

  Reference _nullableListOf(String entityName) {
    return TypeReference(
      (b) => b
        ..symbol = 'List'
        ..isNullable = true
        ..types.add(refer(entityName)),
    );
  }

  Reference _nullableType(String symbol) {
    return TypeReference(
      (b) => b
        ..symbol = symbol
        ..isNullable = true,
    );
  }

  Expression _this(String name) => refer('this').property(name);

  List<_BoolField> _boolFieldsForMethods(List<String> methods) {
    final fields = <_BoolField>[];
    for (final method in methods) {
      switch (method) {
        case 'get':
          fields.add(
            _BoolField('isGetting', 'Whether get operation is in progress'),
          );
          break;
        case 'getList':
          fields.add(
            _BoolField(
              'isGettingList',
              'Whether getList operation is in progress',
            ),
          );
          break;
        case 'create':
          fields.add(
            _BoolField('isCreating', 'Whether create operation is in progress'),
          );
          break;
        case 'update':
          fields.add(
            _BoolField('isUpdating', 'Whether update operation is in progress'),
          );
          break;
        case 'delete':
          fields.add(
            _BoolField('isDeleting', 'Whether delete operation is in progress'),
          );
          break;
        case 'watch':
          fields.add(
            _BoolField('isWatching', 'Whether watch operation is in progress'),
          );
          break;
        case 'watchList':
          fields.add(
            _BoolField(
              'isWatchingList',
              'Whether watchList operation is in progress',
            ),
          );
          break;
      }
    }
    return fields;
  }
}

class _BoolField {
  final String name;
  final String doc;

  const _BoolField(this.name, this.doc);
}
