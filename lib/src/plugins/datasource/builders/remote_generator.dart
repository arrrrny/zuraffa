import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/ast/ast_helper.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/plugin_system/plugin_action.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

/// Generates remote data source implementations.
class RemoteDataSourceBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final AppendExecutor appendExecutor;

  RemoteDataSourceBuilder({
    required this.outputDir,
    GeneratorOptions options = const GeneratorOptions(),
    @Deprecated('Use options.dryRun') bool? dryRun,
    @Deprecated('Use options.force') bool? force,
    @Deprecated('Use options.verbose') bool? verbose,
    AppendExecutor? appendExecutor,
  }) : options = options.copyWith(
         dryRun: dryRun ?? options.dryRun,
         force: force ?? options.force,
         verbose: verbose ?? options.verbose,
       ),
       appendExecutor = appendExecutor ?? AppendExecutor();

  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final dataSourceName = '${entityName}RemoteDataSource';
    final fileName = '${entitySnake}_remote_datasource.dart';

    final dataSourceDirPath = path.join(
      outputDir,
      'data',
      'datasources',
      entitySnake,
    );
    final filePath = path.join(dataSourceDirPath, fileName);

    final methods = _buildMethods(config);
    final importPaths = _buildImportPaths(config);

    final content = const SpecLibrary().emitLibrary(
      const SpecLibrary().library(
        specs: [
          Class(
            (c) => c
              ..name = dataSourceName
              ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
              ..implements.add(refer('${entityName}DataSource'))
              ..methods.addAll(methods),
          ),
        ],
        directives: importPaths.map(Directive.import),
      ),
    );

    if (config.action == PluginAction.delete) {
      return FileUtils.deleteFile(
        filePath,
        'datasource_remote',
        dryRun: options.dryRun,
        verbose: options.verbose,
      );
    }

    if (File(filePath).existsSync()) {
      final existing = await File(filePath).readAsString();

      if (config.action == PluginAction.remove) {
        final reverted = _removeMethods(
          source: existing,
          className: dataSourceName,
          methods: methods,
        );
        return FileUtils.writeFile(
          filePath,
          reverted,
          'datasource_remote',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          revert: false,
        );
      }

      if (config.action == PluginAction.add ||
          config.action == PluginAction.create) {
        if (config.action == PluginAction.create && options.force) {
          // Fall through to write new file logic
        } else {
          final importLines = _buildImportLines(importPaths);
          final mergedImports = _mergeImports(existing, importLines);
          final appended = _appendMethods(
            source: mergedImports,
            className: dataSourceName,
            methods: methods,
          );
          return FileUtils.writeFile(
            filePath,
            appended,
            'datasource_remote',
            force: true,
            dryRun: options.dryRun,
            verbose: options.verbose,
            revert: false,
          );
        }
      }
    }

    if (config.action == PluginAction.remove) {
      return GeneratedFile(path: filePath, type: 'datasource_remote', action: 'skipped');
    }

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

  String _removeMethods({
    required String source,
    required String className,
    required List<Method> methods,
  }) {
    var updated = source;
    final helper = const AstHelper();
    for (final method in methods) {
      final methodName = method.name!;
      updated = helper.removeMethodFromClass(
        source: updated,
        className: className,
        methodName: methodName,
      );
    }
    return updated;
  }

  String _appendMethods({
    required String source,
    required String className,
    required List<Method> methods,
  }) {
    var updated = source;
    for (final method in methods) {
      final methodSource = _emitMethod(method);
      final result = appendExecutor.execute(
        AppendRequest.method(
          source: updated,
          className: className,
          memberSource: methodSource,
        ),
      );
      updated = result.source;
    }
    return updated;
  }

  String _mergeImports(String source, List<String> imports) {
    var updated = source;
    for (final importLine in imports) {
      if (!updated.contains(importLine)) {
        updated = '$importLine\n$updated';
      }
    }
    return updated;
  }

  List<String> _buildImportLines(List<String> importPaths) {
    return importPaths.map((path) => "import '$path';").toList();
  }

  String _emitMethod(Method method) {
    final emitter = DartEmitter(
      orderDirectives: true,
      useNullSafetySyntax: true,
    );
    return method.accept(emitter).toString();
  }

  List<String> _buildImportPaths(GeneratorConfig config) {
    final entitySnake = config.nameSnake;
    final imports = [
      'package:zuraffa/zuraffa.dart',
      '../../../domain/entities/$entitySnake/$entitySnake.dart',
      '${entitySnake}_datasource.dart',
    ];

    for (final method in config.methods) {
      final gqlFile = config.generateGql
          ? _graphqlFileName(config, method)
          : null;
      if (gqlFile != null) {
        imports.add('graphql/$gqlFile');
      }
    }
    return imports;
  }

  List<Method> _buildMethods(GeneratorConfig config) {
    final methods = <Method>[];
    final entityName = config.name;
    final entityCamel = config.nameCamel;
    final dataSourceName = '${entityName}RemoteDataSource';

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

    for (final method in config.methods) {
      final gqlConstant = config.generateGql
          ? _graphqlConstantName(config, method)
          : null;

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
                        'UpdateParams<${config.idType}, $dataType>',
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
                      ..type = refer('DeleteParams<${config.idType}>'),
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
          methods.add(
            Method(
              (m) => m
                ..name = method
                ..annotations.add(refer('override'))
                ..returns = refer('Future<void>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('dynamic'),
                  ),
                )
                ..modifier = MethodModifier.async
                ..body = Block(
                  (b) => b
                    ..statements.add(
                      refer('throw UnimplementedError').call([
                        literalString('Implement remote $method'),
                      ]).statement,
                    ),
                ),
            ),
          );
      }
    }
    return methods;
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
