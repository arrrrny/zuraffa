import 'dart:io';
import 'package:code_builder/code_builder.dart';

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';

part 'implementation_generator_append.dart';
part 'implementation_generator_cached.dart';
part 'implementation_generator_simple.dart';

/// Generates repository implementation classes.
///
/// Builds data repository implementations that delegate to data sources,
/// with optional cache integration and append behavior.
///
/// Example:
/// ```dart
/// final generator = RepositoryImplementationGenerator(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final file = await generator.generate(GeneratorConfig(name: 'Product'));
/// ```
class RepositoryImplementationGenerator {
  final String outputDir;
  final GeneratorOptions options;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final AppendExecutor appendExecutor;

  /// Creates a [RepositoryImplementationGenerator].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param options Generation flags for writing behavior and logging.
  /// @param dryRun Deprecated: use [options].
  /// @param force Deprecated: use [options].
  /// @param verbose Deprecated: use [options].
  /// @param appendExecutor Optional append executor override.
  RepositoryImplementationGenerator({
    required this.outputDir,
    GeneratorOptions options = const GeneratorOptions(),
    @Deprecated('Use options.dryRun') bool? dryRun,
    @Deprecated('Use options.force') bool? force,
    @Deprecated('Use options.verbose') bool? verbose,
    AppendExecutor? appendExecutor,
  })  : options = options.copyWith(
          dryRun: dryRun ?? options.dryRun,
          force: force ?? options.force,
          verbose: verbose ?? options.verbose,
        ),
        dryRun = dryRun ?? options.dryRun,
        force = force ?? options.force,
        verbose = verbose ?? options.verbose,
        appendExecutor = appendExecutor ?? AppendExecutor();

  /// Generates a repository implementation for the given [config].
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @returns Generated repository file metadata.
  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final repoName = '${entityName}Repository';
    final dataRepoName = 'Data${entityName}Repository';

    final fileName = 'data_${entitySnake}_repository.dart';
    final filePath = '$outputDir/data/repositories/$fileName';

    final methods = <Method>[];

    final dataSourceName = '${entityName}DataSource';
    final localDataSourceName = '${entityName}LocalDataSource';

    final fields = <Field>[];
    final constructors = <Constructor>[];
    if (config.generateLocal) {
      fields.add(
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer(localDataSourceName)
            ..name = '_dataSource',
        ),
      );
      constructors.add(
        Constructor(
          (c) => c
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = '_dataSource'
                  ..toThis = true,
              ),
            ),
        ),
      );
    } else if (config.enableCache) {
      fields.addAll([
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer(dataSourceName)
            ..name = '_remoteDataSource',
        ),
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer(localDataSourceName)
            ..name = '_localDataSource',
        ),
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer('CachePolicy')
            ..name = '_cachePolicy',
        ),
      ]);
      constructors.add(
        Constructor(
          (c) => c
            ..requiredParameters.addAll([
              Parameter(
                (p) => p
                  ..name = '_remoteDataSource'
                  ..toThis = true,
              ),
              Parameter(
                (p) => p
                  ..name = '_localDataSource'
                  ..toThis = true,
              ),
              Parameter(
                (p) => p
                  ..name = '_cachePolicy'
                  ..toThis = true,
              ),
            ]),
        ),
      );
    } else {
      fields.add(
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer(dataSourceName)
            ..name = '_dataSource',
        ),
      );
      constructors.add(
        Constructor(
          (c) => c
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = '_dataSource'
                  ..toThis = true,
              ),
            ),
        ),
      );
    }

    if (config.generateInit) {
      final isInitializedGetter = Method(
        (m) => m
          ..name = 'isInitialized'
          ..type = MethodType.getter
          ..annotations.add(refer('override'))
          ..returns = refer('Stream<bool>')
          ..body = Block(
            (b) => b
              ..statements.add(
                refer(config.enableCache ? '_remoteDataSource' : '_dataSource')
                    .property('isInitialized')
                    .returned
                    .statement,
              ),
          ),
      );
      final initializeMethod = Method(
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
          ..body = Block(
            (b) => b
              ..statements.add(
                refer(config.enableCache ? '_remoteDataSource' : '_dataSource')
                    .property('initialize')
                    .call([refer('params')])
                    .returned
                    .statement,
              ),
          ),
      );
      methods.add(isInitializedGetter);
      methods.add(initializeMethod);
    }

    for (final method in config.methods) {
      if (config.enableCache) {
        methods.add(
          _generateCachedMethod(config, method, entityName, entityCamel),
        );
      } else {
        methods.add(
          _generateSimpleMethod(config, method, entityName, entityCamel),
        );
      }
    }

    final dataSourceImports = config.generateLocal
        ? ['../data_sources/$entitySnake/${entitySnake}_local_data_source.dart']
        : config.enableCache
            ? [
                '../data_sources/$entitySnake/${entitySnake}_data_source.dart',
                '../data_sources/$entitySnake/${entitySnake}_local_data_source.dart',
              ]
            : ['../data_sources/$entitySnake/${entitySnake}_data_source.dart'];

    final hasWatchMethods = config.methods.any(
      (m) => m == 'watch' || m == 'watchList',
    );
    final includeAsyncImport = config.enableCache && hasWatchMethods;

    final directives = <Directive>[
      if (includeAsyncImport) Directive.import('dart:async'),
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import('../../domain/entities/$entitySnake/$entitySnake.dart'),
      Directive.import(
        '../../domain/repositories/${entitySnake}_repository.dart',
      ),
      ...dataSourceImports.map(Directive.import),
    ];

    final clazz = Class(
      (c) => c
        ..name = dataRepoName
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..implements.add(refer(repoName))
        ..fields.addAll(fields)
        ..constructors.addAll(constructors)
        ..methods.addAll(methods),
    );
    final library = const SpecLibrary().library(
      specs: [clazz],
      directives: directives,
    );
    final content = const SpecLibrary().emitLibrary(library);

    if (config.appendToExisting && File(filePath).existsSync()) {
      final existing = await File(filePath).readAsString();
      final importPaths = _buildImportPaths(config, entitySnake);
      final importLines = _buildImportLines(importPaths);
      final mergedImports = _mergeImports(existing, importLines);
      final appended = _appendMethods(
        source: mergedImports,
        className: dataRepoName,
        methods: methods,
      );
      return FileUtils.writeFile(
        filePath,
        appended,
        'data_repository',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
      );
    }

    return FileUtils.writeFile(
      filePath,
      content,
      'data_repository',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }
}
