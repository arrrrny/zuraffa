import 'package:path/path.dart' as p;
import 'package:code_builder/code_builder.dart';

import '../../../core/ast/append_executor.dart';

import '../../../core/ast/ast_helper.dart';
import '../../../core/ast/augmentation_builder.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/plugin_system/discovery_engine.dart';
import '../../../core/context/file_system.dart';
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
class RepositoryImplementationGenerator {
  final String outputDir;
  final GeneratorOptions options;
  final AppendExecutor appendExecutor;
  final DiscoveryEngine discovery;
  final FileSystem fileSystem;
  final SpecLibrary specLibrary;
  final AugmentationBuilder augmentationBuilder;

  /// Creates a [RepositoryImplementationGenerator].
  RepositoryImplementationGenerator({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.appendExecutor = const AppendExecutor(),
    this.specLibrary = const SpecLibrary(),
    AugmentationBuilder? augmentationBuilder,
    DiscoveryEngine? discovery,
    FileSystem? fileSystem,
  }) : augmentationBuilder =
           augmentationBuilder ?? AugmentationBuilder(outputDir: outputDir),
       fileSystem = fileSystem ?? FileSystem.create(),
       discovery =
           discovery ??
           DiscoveryEngine(
             projectRoot: outputDir,
             fileSystem: fileSystem ?? FileSystem.create(),
           );

  /// Generates a repository implementation for the given [config].
  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final repoName = '${entityName}Repository';
    final dataRepoName = 'Data${entityName}Repository';

    final fileName = 'data_${entitySnake}_repository.dart';
    final filePath = p.join(outputDir, 'data', 'repositories', fileName);

    final methods = <Method>[];

    if (config.isCustomUseCase && config.appendToExisting) {
      methods.add(
        _generateSimpleMethod(
          config,
          config.getRepoMethodName(),
          entityName,
          entityCamel,
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
      fields.add(
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer('CachePolicy')
            ..name = '_cachePolicy',
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
            )
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = '_cachePolicy'
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
    if (await fileSystem.exists(filePath) &&
        (config.appendToExisting || !config.force)) {
      final existing = await fileSystem.read(filePath);

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
              directives: importPaths.toSet().map(Directive.import),
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
            fileSystem: fileSystem,
          );
        }

        // Handle Revert for Append (remove methods from augmentation)
        await augmentationBuilder.remove(
          hostPath: filePath,
          className: dataRepoName,
          members: methods,
          dryRun: options.dryRun,
        );

        var source = existing;
        final augmentFileName = p
            .basename(filePath)
            .replaceFirst('.dart', '.augment.dart');
        source = const AstHelper().removeAugment(
          source: source,
          augmentPath: augmentFileName,
        );

        // Also clean up any extra fields that were added
        for (final field in fields) {
          source = const AstHelper().removeFieldFromClass(
            source: source,
            className: dataRepoName,
            fieldName: field.name,
          );
        }

        if (const AstHelper().isClassEmpty(source, dataRepoName)) {
          return FileUtils.deleteFile(
            filePath,
            'repository_implementation',
            dryRun: options.dryRun,
            verbose: options.verbose,
            fileSystem: fileSystem,
          );
        }

        return FileUtils.writeFile(
          filePath,
          source,
          'repository_implementation',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          revert: false,
          fileSystem: fileSystem,
        );
      }

      if (config.appendToExisting) {
        var source = existing;
        final augmentFileName = p
            .basename(filePath)
            .replaceFirst('.dart', '.augment.dart');

        // 1. Add 'import augment' to host file
        source = const AstHelper().addAugment(
          source: source,
          augmentPath: augmentFileName,
        );

        // 2. Add missing imports to host file
        for (final importPath in importPaths) {
          source = const AstHelper().addImport(
            source: source,
            importPath: importPath,
          );
        }

        // 3. Add missing fields to host file
        for (final field in fields) {
          final fieldSource = field
              .accept(DartEmitter(useNullSafetySyntax: true))
              .toString();
          if (!source.contains(
            'final ${field.type?.accept(DartEmitter())} ${field.name};',
          )) {
            source = const AstHelper().addFieldToClass(
              source: source,
              className: dataRepoName,
              fieldSource: fieldSource,
            );
          }
        }

        await FileUtils.writeFile(
          filePath,
          source,
          'repository_implementation',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          fileSystem: fileSystem,
        );

        // 4. Generate/Update the augmentation file
        final augmentationFile = await augmentationBuilder.generate(
          hostPath: filePath,
          className: dataRepoName,
          members: methods,
          imports: importPaths,
          dryRun: options.dryRun,
        );

        return GeneratedFile(
          path: augmentationFile.path,
          type: 'repository_implementation',
          action: 'updated',
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
        directives: importPaths.toSet().map(Directive.import),
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
      fileSystem: fileSystem,
    );
  }
}
