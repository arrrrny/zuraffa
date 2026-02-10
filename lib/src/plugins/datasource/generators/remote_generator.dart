import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

class RemoteDataSourceGenerator {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;

  RemoteDataSourceGenerator({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    SpecLibrary? specLibrary,
  }) : specLibrary = specLibrary ?? const SpecLibrary();

  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final dataSourceName = '${entityName}RemoteDataSource';
    final fileName = '${entitySnake}_remote_data_source.dart';

    final dataSourceDirPath = path.join(
      outputDir,
      'data',
      'data_sources',
      entitySnake,
    );
    final filePath = path.join(dataSourceDirPath, fileName);

    final methods = <Method>[];
    if (config.generateInit) {
      methods.add(
        Method(
          (m) => m
            ..name = 'initialize'
            ..annotations.add(CodeExpression(Code('override')))
            ..returns = refer('Future<void>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('InitializationParams'),
              ),
            )
            ..modifier = MethodModifier.async
            ..body = Code('''
logger.info('Initializing $dataSourceName');
logger.info('$dataSourceName initialized');
'''),
        ),
      );
      methods.add(
        Method(
          (m) => m
            ..name = 'isInitialized'
            ..type = MethodType.getter
            ..annotations.add(CodeExpression(Code('override')))
            ..returns = refer('Stream<bool>')
            ..body = Code('return Stream.value(true);'),
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
            _buildMethod(
              name: 'get',
              returnType: 'Future<$entityName>',
              parameters: [_param('params', 'QueryParams<$entityName>')],
              body: _remoteBody('Implement remote get', gqlConstant),
              isAsync: true,
            ),
          );
          break;
        case 'getList':
          methods.add(
            _buildMethod(
              name: 'getList',
              returnType: 'Future<List<$entityName>>',
              parameters: [_param('params', 'ListQueryParams<$entityName>')],
              body: _remoteBody('Implement remote getList', gqlConstant),
              isAsync: true,
            ),
          );
          break;
        case 'create':
          methods.add(
            _buildMethod(
              name: 'create',
              returnType: 'Future<$entityName>',
              parameters: [_param(entityCamel, entityName)],
              body: _remoteBody('Implement remote create', gqlConstant),
              isAsync: true,
            ),
          );
          break;
        case 'update':
          final dataType = config.useZorphy
              ? '${config.name}Patch'
              : 'Partial<${config.name}>';
          methods.add(
            _buildMethod(
              name: 'update',
              returnType: 'Future<${config.name}>',
              parameters: [
                _param('params', 'UpdateParams<${config.idType}, $dataType>'),
              ],
              body: _remoteBody('Implement remote update', gqlConstant),
              isAsync: true,
            ),
          );
          break;
        case 'delete':
          methods.add(
            _buildMethod(
              name: 'delete',
              returnType: 'Future<void>',
              parameters: [_param('params', 'DeleteParams<${config.idType}>')],
              body: _remoteBody('Implement remote delete', gqlConstant),
              isAsync: true,
            ),
          );
          break;
        case 'watch':
          methods.add(
            _buildMethod(
              name: 'watch',
              returnType: 'Stream<$entityName>',
              parameters: [_param('params', 'QueryParams<$entityName>')],
              body: _remoteBody('Implement remote watch', gqlConstant),
              isAsync: false,
            ),
          );
          break;
        case 'watchList':
          methods.add(
            _buildMethod(
              name: 'watchList',
              returnType: 'Stream<List<$entityName>>',
              parameters: [_param('params', 'ListQueryParams<$entityName>')],
              body: _remoteBody('Implement remote watchList', gqlConstant),
              isAsync: false,
            ),
          );
          break;
      }
    }

    final clazz = Class(
      (b) => b
        ..name = dataSourceName
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..implements.add(refer('${entityName}DataSource'))
        ..methods.addAll(methods),
    );

    final directives = <Directive>[
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import(
        '../../../domain/entities/$entitySnake/$entitySnake.dart',
      ),
      Directive.import('${entitySnake}_data_source.dart'),
      ...gqlImports.map(Directive.import),
    ];

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'remote_datasource',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Method _buildMethod({
    required String name,
    required String returnType,
    required List<Parameter> parameters,
    required String body,
    required bool isAsync,
  }) {
    return Method(
      (m) => m
        ..name = name
        ..annotations.add(CodeExpression(Code('override')))
        ..returns = refer(returnType)
        ..requiredParameters.addAll(parameters)
        ..modifier = isAsync ? MethodModifier.async : null
        ..body = Code(body),
    );
  }

  Parameter _param(String name, String type) {
    return Parameter(
      (p) => p
        ..name = name
        ..type = refer(type),
    );
  }

  String _remoteBody(String fallback, String? gqlConstant) {
    if (gqlConstant != null) {
      return 'throw UnimplementedError($gqlConstant);';
    }
    return "throw UnimplementedError('$fallback');";
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
    if (config.gqlType != null) {
      return config.gqlType!;
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
