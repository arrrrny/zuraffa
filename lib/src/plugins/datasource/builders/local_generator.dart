import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/ast/ast_helper.dart';
import '../../../core/generator_options.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/context/file_system.dart';
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
class LocalDataSourceBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final AppendExecutor appendExecutor;
  final FileSystem fileSystem;

  /// Creates a [LocalDataSourceBuilder].
  LocalDataSourceBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    AppendExecutor? appendExecutor,
    FileSystem? fileSystem,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       appendExecutor = appendExecutor ?? AppendExecutor(),
       fileSystem = fileSystem ?? FileSystem.create();

  /// Generates a local data source file for the given [config].
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

    final directives = <Directive>[
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

    if (await fileSystem.exists(filePath) &&
        (config.appendToExisting || !options.force)) {
      final existing = await fileSystem.read(filePath);

      if (config.revert) {
        if (!config.appendToExisting) {
          return FileUtils.deleteFile(
            filePath,
            'local_datasource',
            dryRun: options.dryRun,
            verbose: options.verbose,
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
                  className: dataSourceName,
                  memberSource: methodSource,
                ),
              )
              .source;
        }

        // 2. Remove constructors
        for (final constructor in constructors) {
          final tempClass = Class(
            (b) => b
              ..name = dataSourceName
              ..constructors.add(constructor),
          );
          final classSource = tempClass.accept(emitter).toString();
          final start = classSource.indexOf('$dataSourceName(');
          final end = classSource.lastIndexOf(';') != -1
              ? classSource.lastIndexOf(';') + 1
              : classSource.lastIndexOf('}') + 1;
          final constructorSource = classSource.substring(start, end);

          source = appendExecutor
              .undo(
                AppendRequest.constructor(
                  source: source,
                  className: dataSourceName,
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
                  className: dataSourceName,
                  memberSource: fieldSource,
                ),
              )
              .source;
        }

        if (const AstHelper().isClassEmpty(source, dataSourceName)) {
          return FileUtils.deleteFile(
            filePath,
            'local_datasource',
            dryRun: options.dryRun,
            verbose: options.verbose,
            fileSystem: fileSystem,
          );
        }

        return FileUtils.writeFile(
          filePath,
          source,
          'local_datasource',
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

        // 2. Add missing fields
        for (final field in fields) {
          final fieldSource = field.accept(emitter).toString();
          source = appendExecutor
              .execute(
                AppendRequest.field(
                  source: source,
                  className: dataSourceName,
                  memberSource: fieldSource,
                ),
              )
              .source;
        }

        // 3. Add missing constructors
        for (final constructor in constructors) {
          final tempClass = Class(
            (b) => b
              ..name = dataSourceName
              ..constructors.add(constructor),
          );
          final classSource = tempClass.accept(emitter).toString();
          final start = classSource.indexOf('$dataSourceName(');
          final end = classSource.lastIndexOf(';') != -1
              ? classSource.lastIndexOf(';') + 1
              : classSource.lastIndexOf('}') + 1;
          final constructorSource = classSource.substring(start, end);

          source = appendExecutor
              .execute(
                AppendRequest.constructor(
                  source: source,
                  className: dataSourceName,
                  memberSource: constructorSource,
                ),
              )
              .source;
        }

        // 4. Add missing methods
        for (final method in methods) {
          final methodSource = method.accept(emitter).toString();
          source = appendExecutor
              .execute(
                AppendRequest.method(
                  source: source,
                  className: dataSourceName,
                  memberSource: methodSource,
                ),
              )
              .source;
        }

        await FileUtils.writeFile(
          filePath,
          source,
          'local_datasource',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          fileSystem: fileSystem,
        );

        return GeneratedFile(
          path: filePath,
          type: 'local_datasource',
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
      'local_datasource',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fileSystem,
    );
  }
}
