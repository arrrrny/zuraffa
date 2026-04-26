import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/ast/ast_helper.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../../../utils/entity_utils.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';

/// Generates data source interfaces for domain and data layers.
class DataSourceInterfaceBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final AppendExecutor appendExecutor;
  final FileSystem fileSystem;

  DataSourceInterfaceBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    AppendExecutor? appendExecutor,
    FileSystem? fileSystem,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       appendExecutor = appendExecutor ?? AppendExecutor(),
       fileSystem = fileSystem ?? FileSystem.create();

  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final entityName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    final entitySnake = StringUtils.camelToSnake(entityName);
    final entityCamel = StringUtils.pascalToCamel(entityName);
    final dataSourceName = '${entityName}DataSource';
    final fileName = '${entitySnake}_datasource.dart';

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
            ..returns = refer(returnType)
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer(paramsType),
              ),
            ),
        ),
      );
    }

    if (config.generateInit) {
      methods.add(
        Method(
          (m) => m
            ..name = 'isInitialized'
            ..type = MethodType.getter
            ..returns = refer('Stream<bool>'),
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
            ),
        ),
      );
      methods.add(
        Method(
          (m) => m
            ..name = 'dispose'
            ..returns = refer('Future<void>'),
        ),
      );
    }

    for (final method in config.methods) {
      switch (method) {
        case 'get':
          methods.add(
            Method(
              (m) => m
                ..name = 'get'
                ..returns = refer('Future<$entityName>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('QueryParams<$entityName>'),
                  ),
                ),
            ),
          );
          break;
        case 'getList':
          methods.add(
            Method(
              (m) => m
                ..name = 'getList'
                ..returns = refer('Future<List<$entityName>>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('ListQueryParams<$entityName>'),
                  ),
                ),
            ),
          );
          break;
        case 'create':
          methods.add(
            Method(
              (m) => m
                ..name = 'create'
                ..returns = refer('Future<$entityName>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = entityCamel
                      ..type = refer(entityName),
                  ),
                ),
            ),
          );
          break;
        case 'update':
          // Use Patch for entity-based updates by default
          final dataType = '${config.name}Patch';
          methods.add(
            Method(
              (m) => m
                ..name = 'update'
                ..returns = refer('Future<${config.name}>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(
                        'UpdateParams<${config.idFieldType}, $dataType>',
                      ),
                  ),
                ),
            ),
          );
          break;
        case 'toggle':
          final fieldEnum = '${config.name}Fields';
          methods.add(
            Method(
              (m) => m
                ..name = 'toggle'
                ..returns = refer('Future<${config.name}>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(
                        'ToggleParams<${config.idFieldType}, $fieldEnum>',
                      ),
                  ),
                ),
            ),
          );
          break;
        case 'delete':
          methods.add(
            Method(
              (m) => m
                ..name = 'delete'
                ..returns = refer('Future<void>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('DeleteParams<${config.idFieldType}>'),
                  ),
                ),
            ),
          );
          break;
        case 'watch':
          methods.add(
            Method(
              (m) => m
                ..name = 'watch'
                ..returns = refer('Stream<$entityName>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('QueryParams<$entityName>'),
                  ),
                ),
            ),
          );
          break;
        case 'watchList':
          methods.add(
            Method(
              (m) => m
                ..name = 'watchList'
                ..returns = refer('Stream<List<$entityName>>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('ListQueryParams<$entityName>'),
                  ),
                ),
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
    ];
    final clazz = Class(
      (c) => c
        ..name = dataSourceName
        ..abstract = true
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..methods.addAll(methods),
    );

    if (await fileSystem.exists(filePath) &&
        (config.appendToExisting || !config.force)) {
      if (config.revert) {
        if (!config.appendToExisting) {
          return FileUtils.deleteFile(
            filePath,
            'datasource',
            dryRun: options.dryRun,
            verbose: options.verbose,
            fileSystem: fileSystem,
          );
        }

        var source = await fileSystem.read(filePath);
        final emitter = DartEmitter(useNullSafetySyntax: true);

        // 1. Remove methods directly from host file
        for (final method in methods) {
          final methodSource = method.accept(emitter).toString();
          final request = AppendRequest.method(
            source: source,
            className: dataSourceName,
            memberSource: methodSource,
          );
          source = appendExecutor.undo(request).source;
        }

        if (const AstHelper().isClassEmpty(source, dataSourceName)) {
          return FileUtils.deleteFile(
            filePath,
            'datasource',
            dryRun: options.dryRun,
            verbose: options.verbose,
            fileSystem: fileSystem,
          );
        }

        return FileUtils.writeFile(
          filePath,
          source,
          'datasource',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          revert: false,
          fileSystem: fileSystem,
        );
      }

      if (config.appendToExisting) {
        var source = await fileSystem.read(filePath);
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

        // 2. Add methods directly to host file
        for (final method in methods) {
          final methodSource = method.accept(emitter).toString();
          final request = AppendRequest.method(
            source: source,
            className: dataSourceName,
            memberSource: methodSource,
          );
          source = appendExecutor.execute(request).source;
        }

        await FileUtils.writeFile(
          filePath,
          source,
          'datasource',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          fileSystem: fileSystem,
        );

        return GeneratedFile(
          path: filePath,
          type: 'datasource',
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
      'datasource',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fileSystem,
    );
  }
}
