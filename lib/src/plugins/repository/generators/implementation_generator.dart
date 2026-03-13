import 'dart:io';
import 'package:code_builder/code_builder.dart';

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/entity_analyzer.dart';

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
  final AppendExecutor appendExecutor;

  final SpecLibrary specLibrary;

  /// Creates a [RepositoryImplementationGenerator].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param options Generation flags for writing behavior and logging.
  /// @param dryRun Deprecated: use [options].
  /// @param force Deprecated: use [options].
  /// @param verbose Deprecated: use [options].
  /// @param appendExecutor Optional append executor override.
  /// @param specLibrary Optional spec library override.
  RepositoryImplementationGenerator({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.appendExecutor = const AppendExecutor(),
    this.specLibrary = const SpecLibrary(),
  });

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

    // If action is delete, delete the file
    if (config.revert) {
      return FileUtils.deleteFile(
        filePath,
        'repository_implementation',
        dryRun: options.dryRun,
        verbose: options.verbose,
      );
    }

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
      fields.add(
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer(dataSourceName)
            ..name = '_remoteDataSource',
        ),
      );
      fields.add(
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer(localDataSourceName)
            ..name = '_localDataSource',
        ),
      );
      constructors.add(
        Constructor(
          (c) => c
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = '_remoteDataSource'
                  ..toThis = true,
              ),
            )
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = '_localDataSource'
                  ..toThis = true,
              ),
            ),
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

    if (config.enableCache) {
      for (final method in config.methods) {
        methods.add(
          _generateCachedMethod(config, method, entityName, entityCamel),
        );
      }
    } else {
      for (final method in config.methods) {
        methods.add(
          _generateSimpleMethod(config, method, entityName, entityCamel),
        );
      }
    }

    if (config.generateInit) {
      final targetDataSource =
          config.enableCache ? '_localDataSource' : '_dataSource';
      methods.add(
        Method(
          (m) => m
            ..name = 'isInitialized'
            ..returns = refer('Stream<bool>')
            ..type = MethodType.getter
            ..annotations.add(refer('override'))
            ..body = refer(targetDataSource).property('isInitialized').code,
        ),
      );
      methods.add(
        Method(
          (m) => m
            ..name = 'initialize'
            ..returns = refer('Future<void>')
            ..annotations.add(refer('override'))
            ..modifier = MethodModifier.async
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('InitializationParams'),
              ),
            )
            ..body = Block((b) {
              if (config.enableCache) {
                b.statements.add(
                  refer('_remoteDataSource')
                      .property('initialize')
                      .call([refer('params')])
                      .awaited
                      .statement,
                );
                b.statements.add(
                  refer('_localDataSource')
                      .property('initialize')
                      .call([refer('params')])
                      .awaited
                      .statement,
                );
              } else {
                b.statements.add(
                  refer('_dataSource')
                      .property('initialize')
                      .call([refer('params')])
                      .awaited
                      .statement,
                );
              }
            }),
        ),
      );
      methods.add(
        Method(
          (m) => m
            ..name = 'dispose'
            ..returns = refer('Future<void>')
            ..annotations.add(refer('override'))
            ..modifier = MethodModifier.async
            ..body = Block((b) {
              if (config.enableCache) {
                b.statements.add(
                  refer('_remoteDataSource')
                      .property('dispose')
                      .call([])
                      .awaited
                      .statement,
                );
                b.statements.add(
                  refer('_localDataSource')
                      .property('dispose')
                      .call([])
                      .awaited
                      .statement,
                );
              } else {
                b.statements.add(
                  refer('_dataSource')
                      .property('dispose')
                      .call([])
                      .awaited
                      .statement,
                );
              }
            }),
        ),
      );
    }

    final importPaths = _buildImportPaths(config, entitySnake);

    // If file exists, handle append/remove/add
    if (File(filePath).existsSync() && !config.force) {
      final existing = await File(filePath).readAsString();

      /*
      if (config.action == PluginAction.remove) {
        // Remove methods
        final reverted = _removeMethods(
          source: existing,
          className: dataRepoName,
          methods: methods,
        );
        return FileUtils.writeFile(
          filePath,
          reverted,
          'repository_implementation',
          force: true,
          dryRun: dryRun,
          verbose: verbose,
          revert: false,
        );
      }
      */

      if (config.appendToExisting) {
        // Append methods
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
          'repository_implementation',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          revert: false,
        );
      }
    }

    /*
    if (config.action == PluginAction.remove) {
      return GeneratedFile(
        path: filePath,
        type: 'repository_implementation',
        action: 'skipped',
      );
    }
    */

    final clazz = Class(
      (c) => c
        ..name = dataRepoName
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..implements.add(refer(repoName))
        ..fields.addAll(fields)
        ..constructors.addAll(constructors)
        ..methods.addAll(methods),
    );

    final output = specLibrary.emitLibrary(
      specLibrary.library(
        specs: [clazz],
        directives: importPaths.map(Directive.import),
      ),
      leadingComment:
          '// Generated by zfa\n// zfa generate ${config.name} --methods=${config.methods.join(',')} --repository',
    );

    return FileUtils.writeFile(
      filePath,
      output,
      'repository_implementation',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
    );
  }
}
