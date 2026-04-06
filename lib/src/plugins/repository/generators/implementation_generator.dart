import 'package:path/path.dart' as p;
import 'package:code_builder/code_builder.dart';

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';

import '../../../core/ast/ast_helper.dart';
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

  /// Creates a [RepositoryImplementationGenerator].
  RepositoryImplementationGenerator({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.appendExecutor = const AppendExecutor(),
    this.specLibrary = const SpecLibrary(),
    DiscoveryEngine? discovery,
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create(),
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

        var source = existing;
        final emitter = DartEmitter(useNullSafetySyntax: true);

        // 1. Remove methods
        for (final method in methods) {
          final methodSource = method.accept(emitter).toString();
          source = appendExecutor
              .undo(
                AppendRequest.method(
                  source: source,
                  className: dataRepoName,
                  memberSource: methodSource,
                ),
              )
              .source;
        }

        // 2. Remove constructors
        for (final constructor in constructors) {
          final tempClass = Class(
            (b) => b
              ..name = dataRepoName
              ..constructors.add(constructor),
          );
          final classSource = tempClass.accept(emitter).toString();
          // Extract constructor source - look for className(
          final start = classSource.indexOf('$dataRepoName(');
          final end = classSource.lastIndexOf(';') != -1
              ? classSource.lastIndexOf(';') + 1
              : classSource.lastIndexOf('}') + 1;
          final constructorSource = classSource.substring(start, end);

          source = appendExecutor
              .undo(
                AppendRequest.constructor(
                  source: source,
                  className: dataRepoName,
                  memberSource: constructorSource,
                ),
              )
              .source;
        }

        // 3. Remove fields
        for (final field in fields) {
          final fieldSource = field.accept(emitter).toString();
          source = appendExecutor
              .undo(
                AppendRequest.field(
                  source: source,
                  className: dataRepoName,
                  memberSource: fieldSource,
                ),
              )
              .source;
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
        final emitter = DartEmitter(useNullSafetySyntax: true);

        // 1. Add missing imports to host file
        for (final importPath in importPaths) {
          source = const AstHelper().addImport(
            source: source,
            importPath: importPath,
          );
        }

        // 2. Add missing fields to host file
        for (final field in fields) {
          final fieldSource = field.accept(emitter).toString();
          source = appendExecutor
              .execute(
                AppendRequest.field(
                  source: source,
                  className: dataRepoName,
                  memberSource: fieldSource,
                ),
              )
              .source;
        }

        // 3. Add missing constructors to host file
        for (final constructor in constructors) {
          final tempClass = Class(
            (b) => b
              ..name = dataRepoName
              ..constructors.add(constructor),
          );
          final classSource = tempClass.accept(emitter).toString();
          final start = classSource.indexOf('$dataRepoName(');
          final end = classSource.lastIndexOf(';') != -1
              ? classSource.lastIndexOf(';') + 1
              : classSource.lastIndexOf('}') + 1;
          final constructorSource = classSource.substring(start, end);

          source = appendExecutor
              .execute(
                AppendRequest.constructor(
                  source: source,
                  className: dataRepoName,
                  memberSource: constructorSource,
                ),
              )
              .source;
        }

        // 4. Add missing methods to host file
        for (final method in methods) {
          final methodSource = method.accept(emitter).toString();
          source = appendExecutor
              .execute(
                AppendRequest.method(
                  source: source,
                  className: dataRepoName,
                  memberSource: methodSource,
                ),
              )
              .source;
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

        return GeneratedFile(
          path: filePath,
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
