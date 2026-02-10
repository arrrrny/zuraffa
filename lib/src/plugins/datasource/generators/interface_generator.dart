import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';

class DataSourceInterfaceGenerator {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;

  DataSourceInterfaceGenerator({
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
    final dataSourceName = '${entityName}DataSource';
    final fileName = '${entitySnake}_data_source.dart';

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
            ..name = 'isInitialized'
            ..type = MethodType.getter
            ..returns = refer('Stream<bool>')
            ..body = Code('throw UnimplementedError();'),
        ),
      );
      methods.add(
        Method(
          (m) => m
            ..name = 'initialize'
            ..returns = refer('Future<void>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('InitializationParams'),
              ),
            )
            ..body = Code('throw UnimplementedError();'),
        ),
      );
    }

    for (final method in config.methods) {
      switch (method) {
        case 'get':
          methods.add(
            _abstractMethod(
              name: 'get',
              returnType: 'Future<$entityName>',
              parameters: [_param('params', 'QueryParams<$entityName>')],
            ),
          );
          break;
        case 'getList':
          methods.add(
            _abstractMethod(
              name: 'getList',
              returnType: 'Future<List<$entityName>>',
              parameters: [_param('params', 'ListQueryParams<$entityName>')],
            ),
          );
          break;
        case 'create':
          methods.add(
            _abstractMethod(
              name: 'create',
              returnType: 'Future<$entityName>',
              parameters: [_param(entityCamel, entityName)],
            ),
          );
          break;
        case 'update':
          final dataType = config.useZorphy
              ? '${config.name}Patch'
              : 'Partial<${config.name}>';
          methods.add(
            _abstractMethod(
              name: 'update',
              returnType: 'Future<${config.name}>',
              parameters: [
                _param('params', 'UpdateParams<${config.idType}, $dataType>'),
              ],
            ),
          );
          break;
        case 'delete':
          methods.add(
            _abstractMethod(
              name: 'delete',
              returnType: 'Future<void>',
              parameters: [_param('params', 'DeleteParams<${config.idType}>')],
            ),
          );
          break;
        case 'watch':
          methods.add(
            _abstractMethod(
              name: 'watch',
              returnType: 'Stream<$entityName>',
              parameters: [_param('params', 'QueryParams<$entityName>')],
            ),
          );
          break;
        case 'watchList':
          methods.add(
            _abstractMethod(
              name: 'watchList',
              returnType: 'Stream<List<$entityName>>',
              parameters: [_param('params', 'ListQueryParams<$entityName>')],
            ),
          );
          break;
      }
    }

    final clazz = Class(
      (b) => b
        ..name = dataSourceName
        ..abstract = true
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..methods.addAll(methods),
    );

    final directives = <Directive>[
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import(
        '../../../domain/entities/$entitySnake/$entitySnake.dart',
      ),
    ];

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'datasource',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Method _abstractMethod({
    required String name,
    required String returnType,
    required List<Parameter> parameters,
  }) {
    return Method(
      (m) => m
        ..name = name
        ..returns = refer(returnType)
        ..requiredParameters.addAll(parameters)
        ..body = Code('throw UnimplementedError();'),
    );
  }

  Parameter _param(String name, String type) {
    return Parameter(
      (p) => p
        ..name = name
        ..type = refer(type),
    );
  }
}
