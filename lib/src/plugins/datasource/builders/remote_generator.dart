import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/ast/ast_helper.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../../../utils/entity_utils.dart';
import '../../../core/builder/shared/spec_library.dart';

/// Generates remote data source implementations.
class RemoteDataSourceBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final AppendExecutor appendExecutor;
  final FileSystem fileSystem;

  /// Creates a [RemoteDataSourceBuilder].
  RemoteDataSourceBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    AppendExecutor? appendExecutor,
    FileSystem? fileSystem,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       appendExecutor = appendExecutor ?? AppendExecutor(),
       fileSystem = fileSystem ?? FileSystem.create();

  /// Generates a remote data source file for the given [config].
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

    if (config.isCustomUseCase && config.appendToExisting) {
      final methodName = config.getRepoMethodName();
      var returnType = config.returnsType ?? 'void';
      final paramsType = config.paramsType ?? 'NoParams';

      // Wrap in Future/Stream if not already
      if (config.useCaseType == 'stream' ||
          config.useCaseType == 'streamusecase') {
        if (!returnType.startsWith('Stream<')) {
          returnType = 'Stream<$returnType>';
        }
      } else if (config.useCaseType != 'sync' &&
          config.useCaseType != 'syncusecase') {
        if (!returnType.startsWith('Future<')) {
          returnType = 'Future<$returnType>';
        }
      }

      methods.add(
        Method(
          (m) => m
            ..name = methodName
            ..annotations.add(refer('override'))
            ..returns = refer(returnType)
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer(paramsType),
              ),
            )
            ..modifier = MethodModifier.async
            ..body = _remoteBody('Implement remote $methodName', null),
        ),
      );
    }

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
      methods.add(
        Method(
          (m) => m
            ..name = 'dispose'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<void>')
            ..modifier = MethodModifier.async
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('logger').property('info').call([
                    literalString('Disposing $dataSourceName'),
                  ]).statement,
                )
                ..statements.add(
                  refer('logger').property('info').call([
                    literalString('$dataSourceName disposed'),
                  ]).statement,
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
          final dataType = config.useZorphy
              ? '${config.name}Patch'
              : 'Partial<${config.name}>';
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
        case 'toggle':
          final fieldEnum = '${config.name}Fields';
          methods.add(
            Method(
              (m) => m
                ..name = 'toggle'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<${config.name}>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(
                        'ToggleParams<${config.idFieldType}, $fieldEnum>',
                      ),
                  ),
                )
                ..modifier = MethodModifier.async
                ..body = _remoteBody('Implement remote toggle', gqlConstant),
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

    if (await fileSystem.exists(filePath) &&
        (config.appendToExisting || !options.force)) {
      final existing = await fileSystem.read(filePath);

      if (config.revert) {
        if (!config.appendToExisting) {
          return FileUtils.deleteFile(
            filePath,
            'remote_datasource',
            dryRun: options.dryRun,
            verbose: options.verbose,
            fileSystem: fileSystem,
          );
        }

        var source = existing;
        final emitter = DartEmitter(useNullSafetySyntax: true);

        // 1. Remove methods
        for (final method in methods) {
          final methodSource = method.accept(emitter).toString();
          source = appendExecutor
              .undo(
                AppendRequest.method(
                  source: source,
                  className: dataSourceName,
                  memberSource: methodSource,
                ),
              )
              .source;
        }

        if (const AstHelper().isClassEmpty(source, dataSourceName)) {
          return FileUtils.deleteFile(
            filePath,
            'remote_datasource',
            dryRun: options.dryRun,
            verbose: options.verbose,
            fileSystem: fileSystem,
          );
        }

        return FileUtils.writeFile(
          filePath,
          source,
          'remote_datasource',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          revert: false,
          fileSystem: fileSystem,
        );
      }

      if (config.appendToExisting) {
        var source = existing;
        final emitter = DartEmitter(useNullSafetySyntax: true);

        // 1. Add missing imports
        final importPaths = directives
            .map((d) => (d as dynamic).url as String)
            .toList();
        for (final importPath in importPaths) {
          source = const AstHelper().addImport(
            source: source,
            importPath: importPath,
          );
        }

        // 2. Add missing methods directly to host file
        for (final method in methods) {
          final methodSource = method.accept(emitter).toString();
          source = appendExecutor
              .execute(
                AppendRequest.method(
                  source: source,
                  className: dataSourceName,
                  memberSource: methodSource,
                ),
              )
              .source;
        }

        await FileUtils.writeFile(
          filePath,
          source,
          'remote_datasource',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          fileSystem: fileSystem,
        );

        return GeneratedFile(
          path: filePath,
          type: 'remote_datasource',
          action: 'updated',
        );
      }
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
      fileSystem: fileSystem,
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
