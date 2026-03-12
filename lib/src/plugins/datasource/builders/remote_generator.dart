import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../../../utils/entity_utils.dart';
import '../../../core/builder/shared/spec_library.dart';

/// Generates remote data source implementations.
///
/// Builds remote data source classes with stubbed CRUD and stream methods,
/// including GraphQL hooks when enabled.
///
/// Example:
/// ```dart
/// final builder = RemoteDataSourceBuilder(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final file = await builder.generate(GeneratorConfig(name: 'Product'));
/// ```
class RemoteDataSourceBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final AppendExecutor appendExecutor;

  /// Creates a [RemoteDataSourceBuilder].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param options Generation flags for writing behavior and logging.
  /// @param dryRun Deprecated: use [options].
  /// @param force Deprecated: use [options].
  /// @param verbose Deprecated: use [options].
  /// @param specLibrary Optional spec library override.
  RemoteDataSourceBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    AppendExecutor? appendExecutor,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       appendExecutor = appendExecutor ?? AppendExecutor();

  /// Generates a remote data source file for the given [config].
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @returns Generated data source file metadata.
  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final entityName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    final entitySnake = StringUtils.camelToSnake(entityName);
    final entityCamel = StringUtils.pascalToCamel(entityName);
    final dataSourceName = '${entityName}RemoteDataSource';
    final fileName = '${entitySnake}_remote_datasource.dart';

    final dataSourceDirPath = path.join(
      outputDir,
      'data',
      'datasources',
      entitySnake,
    );
    final filePath = path.join(dataSourceDirPath, fileName);

    final methods = <Method>[];
    if (config.generateInit) {
      methods.add(
        Method(
          (m) => m
            ..name = 'initialize'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<void>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('InitializationParams'),
              ),
            )
            ..modifier = MethodModifier.async
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('logger').property('info').call([
                    literalString('Initializing $dataSourceName'),
                  ]).statement,
                )
                ..statements.add(
                  refer('logger').property('info').call([
                    literalString('$dataSourceName initialized'),
                  ]).statement,
                ),
            ),
        ),
      );
      methods.add(
        Method(
          (m) => m
            ..name = 'isInitialized'
            ..type = MethodType.getter
            ..annotations.add(refer('override'))
            ..returns = refer('Stream<bool>')
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('Stream')
                      .property('value')
                      .call([literalBool(true)])
                      .returned
                      .statement,
                ),
            ),
        ),
      );
    }

    final gqlImports = <String>[];

    for (final method in config.methods) {
      final gqlConstant = config.generateGql
          ? _graphqlConstantName(config, method)
          : null;
      final gqlFile = config.generateGql
          ? _graphqlFileName(config, method)
          : null;
      if (gqlFile != null) {
        gqlImports.add('graphql/$gqlFile');
      }
      switch (method) {
        case 'get':
          methods.add(
            Method(
              (m) => m
                ..name = 'get'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<$entityName>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('QueryParams<$entityName>'),
                  ),
                )
                ..modifier = MethodModifier.async
                ..body = _remoteBody('Implement remote get', gqlConstant),
            ),
          );
          break;
        case 'getList':
          methods.add(
            Method(
              (m) => m
                ..name = 'getList'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<List<$entityName>>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('ListQueryParams<$entityName>'),
                  ),
                )
                ..modifier = MethodModifier.async
                ..body = _remoteBody('Implement remote getList', gqlConstant),
            ),
          );
          break;
        case 'create':
          methods.add(
            Method(
              (m) => m
                ..name = 'create'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<$entityName>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = entityCamel
                      ..type = refer(entityName),
                  ),
                )
                ..modifier = MethodModifier.async
                ..body = _remoteBody('Implement remote create', gqlConstant),
            ),
          );
          break;
        case 'update':
          final dataType = '${config.name}Patch';
          methods.add(
            Method(
              (m) => m
                ..name = 'update'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<${config.name}>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(
                        'UpdateParams<${config.idFieldType}, $dataType>',
                      ),
                  ),
                )
                ..modifier = MethodModifier.async
                ..body = _remoteBody('Implement remote update', gqlConstant),
            ),
          );
          break;
        case 'delete':
          methods.add(
            Method(
              (m) => m
                ..name = 'delete'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<void>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('DeleteParams<${config.idFieldType}>'),
                  ),
                )
                ..modifier = MethodModifier.async
                ..body = _remoteBody('Implement remote delete', gqlConstant),
            ),
          );
          break;
        case 'watch':
          methods.add(
            Method(
              (m) => m
                ..name = 'watch'
                ..annotations.add(refer('override'))
                ..returns = refer('Stream<$entityName>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('QueryParams<$entityName>'),
                  ),
                )
                ..body = _remoteBody('Implement remote watch', gqlConstant),
            ),
          );
          break;
        case 'watchList':
          methods.add(
            Method(
              (m) => m
                ..name = 'watchList'
                ..annotations.add(refer('override'))
                ..returns = refer('Stream<List<$entityName>>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('ListQueryParams<$entityName>'),
                  ),
                )
                ..body = _remoteBody('Implement remote watchList', gqlConstant),
            ),
          );
          break;
        default:
      }
    }

    final directives = <Directive>[
      Directive.import('package:zuraffa/zuraffa.dart'),
      if (config.repo == null)
        Directive.import(
          '../../../domain/entities/$entitySnake/$entitySnake.dart',
        ),
      if (config.isCustomUseCase && config.returnsType != null)
        ...EntityUtils.extractEntityTypes(config.returnsType!).map((type) {
          final snake = StringUtils.camelToSnake(type);
          return Directive.import(
            '../../../domain/entities/$snake/$snake.dart',
          );
        }),
      Directive.import('${entitySnake}_datasource.dart'),
      ...gqlImports.map(Directive.import),
    ];

    final clazz = Class(
      (c) => c
        ..name = dataSourceName
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..implements.add(refer('${entityName}DataSource'))
        ..methods.addAll(methods),
    );

    if (config.appendToExisting &&
        File(filePath).existsSync() &&
        !options.force) {
      final existing = await File(filePath).readAsString();
      var updated = existing;
      for (final method in methods) {
        final methodSource = specLibrary.emitSpec(method);
        final result = appendExecutor.execute(
          AppendRequest.method(
            source: updated,
            className: dataSourceName,
            memberSource: methodSource,
          ),
        );
        updated = result.source;
      }
      return FileUtils.writeFile(
        filePath,
        updated,
        'remote_datasource',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
        revert: false,
      );
    }

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'remote_datasource',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
    );
  }

  Code _remoteBody(String fallback, String? gqlConstant) {
    if (gqlConstant != null) {
      return Block(
        (b) => b
          ..statements.add(
            refer(
              'UnimplementedError',
            ).call([refer(gqlConstant)]).thrown.statement,
          ),
      );
    }
    return Block(
      (b) => b
        ..statements.add(
          refer(
            'UnimplementedError',
          ).call([literalString(fallback)]).thrown.statement,
        ),
    );
  }

  String _graphqlConstantName(GeneratorConfig config, String method) {
    final operationType = _getOperationType(config, method);
    final operationName = _getOperationName(method, config.name);
    return '${StringUtils.pascalToCamel(operationName)}'
        '${StringUtils.convertToPascalCase(operationType)}';
  }

  String _graphqlFileName(GeneratorConfig config, String method) {
    final operationType = _getOperationType(config, method);
    final operationName = _getOperationName(method, config.name);
    return '${StringUtils.camelToSnake(operationName)}_$operationType.dart';
  }

  String _getOperationType(GeneratorConfig config, String method) {
    final gqlType = config.gqlType;
    if (gqlType != null) {
      return gqlType;
    }
    switch (method) {
      case 'get':
      case 'getList':
        return 'query';
      case 'create':
      case 'update':
      case 'delete':
        return 'mutation';
      case 'watch':
      case 'watchList':
        return 'subscription';
      default:
        return 'query';
    }
  }

  String _getOperationName(String method, String entityName) {
    switch (method) {
      case 'get':
        return 'Get$entityName';
      case 'getList':
        return 'Get${entityName}List';
      case 'create':
        return 'Create$entityName';
      case 'update':
        return 'Update$entityName';
      case 'delete':
        return 'Delete$entityName';
      case 'watch':
        return 'Watch$entityName';
      case 'watchList':
        return 'Watch${entityName}List';
      default:
        return method + entityName;
    }
  }
}
