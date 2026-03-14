import 'dart:io';
import 'package:code_builder/code_builder.dart';

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/ast/ast_helper.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/package_utils.dart';

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
      final targetDataSource = config.enableCache
          ? '_localDataSource'
          : '_dataSource';
      methods.add(
        Method(
          (m) => m
            ..name = 'isInitialized'
            ..returns = refer('Stream<bool>')
            ..type = MethodType.getter
            ..annotations.add(refer('override'))
            ..lambda = true
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
                  refer(
                    '_remoteDataSource',
                  ).property('dispose').call([]).awaited.statement,
                );
                b.statements.add(
                  refer(
                    '_localDataSource',
                  ).property('dispose').call([]).awaited.statement,
                );
              } else {
                b.statements.add(
                  refer(
                    '_dataSource',
                  ).property('dispose').call([]).awaited.statement,
                );
              }
            }),
        ),
      );
    }

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

    final importPaths = _buildImportPaths(config, entitySnake);

    // If file exists, handle append/remove/add
    if (File(filePath).existsSync() && !config.force) {
      final existing = await File(filePath).readAsString();

      if (config.revert) {
        if (!config.appendToExisting) {
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
                '// Generated by zfa for: ${config.name}\n// zfa generate ${config.name} --methods=${config.methods.join(',')} --repository',
          );

          return FileUtils.writeFile(
            filePath,
            output,
            'repository_implementation',
            force: true,
            dryRun: options.dryRun,
            verbose: options.verbose,
            revert: true,
            skipRevertIfExisted: true,
          );
        }

        // Remove methods
        var reverted = _removeMethods(
          source: existing,
          className: dataRepoName,
          methods: methods,
        );

        // Remove fields
        reverted = _removeFields(
          source: reverted,
          className: dataRepoName,
          fields: fields,
        );

        // Remove constructors
        reverted = _removeConstructors(
          source: reverted,
          className: dataRepoName,
          constructors: constructors,
        );

        if (const AstHelper().isClassEmpty(reverted, dataRepoName)) {
          return FileUtils.deleteFile(
            filePath,
            'repository_implementation',
            dryRun: options.dryRun,
            verbose: options.verbose,
          );
        }

        return FileUtils.writeFile(
          filePath,
          reverted,
          'repository_implementation',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          revert: false,
        );
      }

      if (config.appendToExisting) {
        var updated = _appendMethods(
          source: existing,
          className: dataRepoName,
          methods: methods,
          imports: importPaths,
        );
        updated = _appendFields(
          source: updated,
          className: dataRepoName,
          fields: fields,
        );
        return FileUtils.writeFile(
          filePath,
          updated,
          'repository_implementation',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
        );
      }

      if (!config.force) {
        return GeneratedFile(
          path: filePath,
          type: 'repository_implementation',
          action: 'skipped',
        );
      }
    }

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
          '// Generated by zfa for: ${config.name}\n// zfa generate ${config.name} --methods=${config.methods.join(',')} --repository',
    );

    return FileUtils.writeFile(
      filePath,
      output,
      'repository_implementation',
      force: config.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
    );
  }
}
