import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/ast/ast_helper.dart';
import '../../../core/generator_options.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../../../utils/entity_utils.dart';

part 'local_crud_methods.dart';
part 'local_generator_impl.dart';
part 'local_helper_methods.dart';
part 'local_stream_methods.dart';

/// Generates local data source implementations.
///
/// Builds local data source classes with CRUD and stream methods, optionally
/// backed by Hive when local caching is enabled.
///
/// Example:
/// ```dart
/// final builder = LocalDataSourceBuilder(
///   outputDir: 'lib/src',
///   dryRun: false,
///   force: true,
///   verbose: false,
/// );
/// final file = await builder.generate(GeneratorConfig(name: 'Product'));
/// ```
class LocalDataSourceBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final AppendExecutor appendExecutor;

  /// Creates a [LocalDataSourceBuilder].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param options Generation flags for writing behavior and logging.
  /// @param dryRun Deprecated: use [options].
  /// @param force Deprecated: use [options].
  /// @param verbose Deprecated: use [options].
  /// @param specLibrary Optional spec library override.
  /// @param appendExecutor Optional append executor override.
  LocalDataSourceBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    AppendExecutor? appendExecutor,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       appendExecutor = appendExecutor ?? AppendExecutor();

  /// Generates a local data source file for the given [config].
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @returns Generated data source file metadata.
  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final entityName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    final entitySnake = StringUtils.camelToSnake(entityName);
    final entityCamel = StringUtils.pascalToCamel(entityName);
    final dataSourceName = '${entityName}LocalDataSource';
    final fileName = '${entitySnake}_local_datasource.dart';

    final dataSourceDirPath = path.join(
      outputDir,
      'data',
      'datasources',
      entitySnake,
    );
    final filePath = path.join(dataSourceDirPath, fileName);

    final useHive = config.generateLocal || config.cacheStorage == 'hive';
    final methods = <Method>[];
    final fields = <Field>[];
    final constructors = <Constructor>[];

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
            ..annotations.add(CodeExpression(Code('override')))
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
            ..annotations.add(CodeExpression(Code('override')))
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

    // If it's a custom usecase, generate a method for it
    if (config.isCustomUseCase) {
      final methodName = StringUtils.pascalToCamel(config.name);
      final returns = config.returnsType ?? 'void';
      methods.add(
        Method(
          (m) => m
            ..name = methodName
            ..annotations.add(CodeExpression(Code('override')))
            ..returns = refer('Future<$returns>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer(config.paramsType ?? 'NoParams'),
              ),
            )
            ..modifier = MethodModifier.async
            ..body = _throwBody('Implement local $methodName'),
        ),
      );
    }

    if (useHive) {
      _generateHiveImplementation(
        config,
        entityName,
        entitySnake,
        entityCamel,
        fields,
        constructors,
        methods,
      );
    } else {
      _generateStubImplementation(config, entityName, entityCamel, methods);
    }

    final clazz = Class(
      (c) => c
        ..name = dataSourceName
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..implements.add(refer('${entityName}DataSource'))
        ..fields.addAll(fields)
        ..constructors.addAll(constructors)
        ..methods.addAll(methods),
    );

    if (File(filePath).existsSync() && !options.force) {
      final existing = await File(filePath).readAsString();

      if (config.revert) {
        if (!config.appendToExisting) {
          return FileUtils.deleteFile(
            filePath,
            'local_datasource',
            dryRun: options.dryRun,
            verbose: options.verbose,
          );
        }

        var updated = existing;
        for (final method in methods) {
          final result = appendExecutor.undo(
            AppendRequest.method(
              source: updated,
              className: dataSourceName,
              memberSource: specLibrary.emitSpec(method),
            ),
          );
          updated = result.source;
        }

        for (final field in fields) {
          final result = appendExecutor.undo(
            AppendRequest.field(
              source: updated,
              className: dataSourceName,
              memberSource: specLibrary.emitSpec(field),
            ),
          );
          updated = result.source;
        }

        for (final _ in constructors) {
          updated = const AstHelper().removeConstructorFromClass(
            source: updated,
            className: dataSourceName,
          );
        }

        if (const AstHelper().isClassEmpty(updated, dataSourceName)) {
          return FileUtils.deleteFile(
            filePath,
            'local_datasource',
            dryRun: options.dryRun,
            verbose: options.verbose,
          );
        }

        return FileUtils.writeFile(
          filePath,
          updated,
          'local_datasource',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          revert: false,
        );
      }

      if (config.appendToExisting) {
        var updated = existing;
        for (final method in methods) {
          final methodSource = specLibrary.emitSpec(method);
          final result = appendExecutor.execute(
            AppendRequest.method(
              source: updated,
              className: dataSourceName,
              memberSource: methodSource,
            ),
          );
          updated = result.source;
        }

        for (final field in fields) {
          final fieldSource = specLibrary.emitSpec(field);
          final result = appendExecutor.execute(
            AppendRequest.field(
              source: updated,
              className: dataSourceName,
              memberSource: fieldSource,
            ),
          );
          updated = result.source;
        }

        return FileUtils.writeFile(
          filePath,
          updated,
          'local_datasource',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          revert: false,
        );
      }
    }

    final directives = <Directive>[
      if (useHive)
        Directive.import('package:hive_ce_flutter/hive_ce_flutter.dart'),
      Directive.import('package:zuraffa/zuraffa.dart'),
      if (config.isEntityBased)
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
    ];

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'local_datasource',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
    );
  }
}
