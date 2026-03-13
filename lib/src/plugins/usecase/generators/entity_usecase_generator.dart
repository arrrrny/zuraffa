import 'dart:io';
import 'package:code_builder/code_builder.dart';

import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/builder/patterns/common_patterns.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

/// Generates entity-based use cases for the domain layer.
///
/// Builds standard CRUD and stream use case classes that delegate to
/// domain repositories.
///
/// Example:
/// ```dart
/// final generator = EntityUseCaseGenerator(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await generator.generate(GeneratorConfig(name: 'Product'));
/// ```
class EntityUseCaseGenerator {
  final String outputDir;
  final GeneratorOptions options;
  final AppendExecutor appendExecutor;

  EntityUseCaseGenerator({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.appendExecutor = const AppendExecutor(),
  });

  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final files = <GeneratedFile>[];
    for (final method in config.methods) {
      files.add(await _generateForMethod(config, method));
    }
    if (config.revert && config.methods.isEmpty) {
      // Revert based on name if no methods specified
      final entitySnake = config.nameSnake;
      final usecaseDirPath = path.join(
        outputDir,
        'domain',
        'usecases',
        config.effectiveDomain,
      );
      final possibleFiles = [
        'get_${entitySnake}_usecase.dart',
        'create_${entitySnake}_usecase.dart',
        'update_${entitySnake}_usecase.dart',
        'delete_${entitySnake}_usecase.dart',
        'watch_${entitySnake}_usecase.dart',
        'get_${entitySnake}_list_usecase.dart',
        'watch_${entitySnake}_list_usecase.dart',
      ];
      for (final fileName in possibleFiles) {
        final filePath = path.join(usecaseDirPath, fileName);
        if (File(filePath).existsSync()) {
          files.add(
            await FileUtils.deleteFile(
              filePath,
              'usecase',
              dryRun: options.dryRun,
              verbose: options.verbose,
            ),
          );
        }
      }
    }
    return files;
  }

  Future<GeneratedFile> _generateForMethod(
    GeneratorConfig config,
    String method,
  ) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final repoName = config.effectiveRepos.first;
    String className;
    TypeReference baseClass;
    Reference paramsType;
    Reference returnType;
    Expression executeExpression;
    bool isStream = false;
    bool isCompletable = false;
    bool needsEntityImport = true;

    switch (method) {
      case 'get':
        className = 'Get${entityName}UseCase';
        if (config.queryFieldType == 'NoParams') {
          baseClass = TypeReference(
            (t) => t
              ..symbol = 'UseCase'
              ..types.addAll([refer(entityName), refer('NoParams')]),
          );
          paramsType = refer('NoParams');
          executeExpression = refer(
            '_repository',
          ).property('get').call([refer('QueryParams').constInstance([])]);
        } else {
          baseClass = TypeReference(
            (t) => t
              ..symbol = 'UseCase'
              ..types.addAll([
                refer(entityName),
                TypeReference(
                  (tr) => tr
                    ..symbol = 'QueryParams'
                    ..types.add(refer(entityName)),
                ),
              ]),
          );
          paramsType = TypeReference(
            (tr) => tr
              ..symbol = 'QueryParams'
              ..types.add(refer(entityName)),
          );
          executeExpression = refer(
            '_repository',
          ).property('get').call([refer('params')]);
        }
        returnType = refer(entityName);
        break;
      case 'getList':
      case 'list':
        className = 'Get${entityName}ListUseCase';
        baseClass = TypeReference(
          (t) => t
            ..symbol = 'UseCase'
            ..types.addAll([
              TypeReference(
                (tr) => tr
                  ..symbol = 'List'
                  ..types.add(refer(entityName)),
              ),
              TypeReference(
                (tr) => tr
                  ..symbol = 'ListQueryParams'
                  ..types.add(refer(entityName)),
              ),
            ]),
        );
        paramsType = TypeReference(
          (tr) => tr
            ..symbol = 'ListQueryParams'
            ..types.add(refer(entityName)),
        );
        returnType = TypeReference(
          (tr) => tr
            ..symbol = 'List'
            ..types.add(refer(entityName)),
        );
        executeExpression = refer(
          '_repository',
        ).property('getList').call([refer('params')]);
        break;
      case 'create':
        className = 'Create${entityName}UseCase';
        baseClass = TypeReference(
          (t) => t
            ..symbol = 'UseCase'
            ..types.addAll([refer(entityName), refer(entityName)]),
        );
        paramsType = refer(entityName);
        returnType = refer(entityName);
        executeExpression = refer(
          '_repository',
        ).property('create').call([refer('params')]);
        break;
      case 'update':
        className = 'Update${entityName}UseCase';
        // Use Patch for entity-based updates by default
        final dataType = '${entityName}Patch';
        baseClass = TypeReference(
          (t) => t
            ..symbol = 'UseCase'
            ..types.addAll([
              refer(entityName),
              TypeReference(
                (tr) => tr
                  ..symbol = 'UpdateParams'
                  ..types.addAll([
                    refer(config.idFieldType),
                    _parseType(dataType, entityName),
                  ]),
              ),
            ]),
        );
        paramsType = TypeReference(
          (tr) => tr
            ..symbol = 'UpdateParams'
            ..types.addAll([
              refer(config.idFieldType),
              _parseType(dataType, entityName),
            ]),
        );
        returnType = refer(entityName);
        executeExpression = refer(
          '_repository',
        ).property('update').call([refer('params')]);
        break;
      case 'delete':
        className = 'Delete${entityName}UseCase';
        baseClass = TypeReference(
          (t) => t
            ..symbol = 'CompletableUseCase'
            ..types.add(
              TypeReference(
                (tr) => tr
                  ..symbol = 'DeleteParams'
                  ..types.add(refer(config.idFieldType)),
              ),
            ),
        );
        paramsType = TypeReference(
          (tr) => tr
            ..symbol = 'DeleteParams'
            ..types.add(refer(config.idFieldType)),
        );
        returnType = refer('void');
        executeExpression = refer(
          '_repository',
        ).property('delete').call([refer('params')]);
        isCompletable = true;
        needsEntityImport = false;
        break;
      case 'watch':
        className = 'Watch${entityName}UseCase';
        if (config.queryFieldType == 'NoParams') {
          baseClass = TypeReference(
            (t) => t
              ..symbol = 'StreamUseCase'
              ..types.addAll([refer(entityName), refer('NoParams')]),
          );
          paramsType = refer('NoParams');
          executeExpression = refer(
            '_repository',
          ).property('watch').call([refer('QueryParams').constInstance([])]);
        } else {
          baseClass = TypeReference(
            (t) => t
              ..symbol = 'StreamUseCase'
              ..types.addAll([
                refer(entityName),
                TypeReference(
                  (tr) => tr
                    ..symbol = 'QueryParams'
                    ..types.add(refer(entityName)),
                ),
              ]),
          );
          paramsType = TypeReference(
            (tr) => tr
              ..symbol = 'QueryParams'
              ..types.add(refer(entityName)),
          );
          executeExpression = refer(
            '_repository',
          ).property('watch').call([refer('params')]);
        }
        returnType = refer(entityName);
        isStream = true;
        break;
      case 'watchList':
        className = 'Watch${entityName}ListUseCase';
        baseClass = TypeReference(
          (t) => t
            ..symbol = 'StreamUseCase'
            ..types.addAll([
              TypeReference(
                (tr) => tr
                  ..symbol = 'List'
                  ..types.add(refer(entityName)),
              ),
              TypeReference(
                (tr) => tr
                  ..symbol = 'ListQueryParams'
                  ..types.add(refer(entityName)),
              ),
            ]),
        );
        paramsType = TypeReference(
          (tr) => tr
            ..symbol = 'ListQueryParams'
            ..types.add(refer(entityName)),
        );
        returnType = TypeReference(
          (tr) => tr
            ..symbol = 'List'
            ..types.add(refer(entityName)),
        );
        executeExpression = refer(
          '_repository',
        ).property('watchList').call([refer('params')]);
        isStream = true;
        break;
      default:
        throw ArgumentError('Unknown method: $method');
    }

    final paramName = 'params';
    final fileSnake = StringUtils.camelToSnake(
      className.replaceAll('UseCase', ''),
    );
    final fileName = '${fileSnake}_usecase.dart';
    final usecaseDirPath = path.join(
      outputDir,
      'domain',
      'usecases',
      config.effectiveDomain,
    );
    final filePath = path.join(usecaseDirPath, fileName);

    final imports = <String>['package:zuraffa/zuraffa.dart'];
    if (needsEntityImport) {
      final entityImports = CommonPatterns.entityImports(
        [
          paramsType.accept(DartEmitter()).toString(),
          returnType.accept(DartEmitter()).toString(),
        ],
        config,
        depth: 2,
        includeDomain: false,
      );
      imports.addAll(entityImports);
    }
    final repoPath =
        '../../repositories/${StringUtils.camelToSnake(repoName.replaceAll('Repository', ''))}_repository.dart';
    imports.add(repoPath);

    final executeMethod = Method((m) {
      m
        ..name = 'execute'
        ..annotations.add(refer('override'))
        ..returns = isStream
            ? TypeReference(
                (tr) => tr
                  ..symbol = 'Stream'
                  ..types.add(returnType),
              )
            : isCompletable
            ? TypeReference(
                (tr) => tr
                  ..symbol = 'Future'
                  ..types.add(refer('void')),
              )
            : TypeReference(
                (tr) => tr
                  ..symbol = 'Future'
                  ..types.add(returnType),
              )
        ..requiredParameters.addAll([
          Parameter(
            (p) => p
              ..name = paramName
              ..type = paramsType,
          ),
          Parameter(
            (p) => p
              ..name = 'cancelToken'
              ..type = TypeReference(
                (tr) => tr
                  ..symbol = 'CancelToken'
                  ..isNullable = true,
              ),
          ),
        ])
        ..modifier = isStream ? null : MethodModifier.async
        ..body = Block(
          (b) => b
            ..statements.add(Code('cancelToken?.throwIfCancelled();'))
            ..statements.add(executeExpression.returned.statement),
        );
    });

    final repoField = Field(
      (f) => f
        ..modifier = FieldModifier.final$
        ..type = refer(repoName)
        ..name = '_repository',
    );
    final ctor = Constructor(
      (c) => c
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = '_repository'
              ..toThis = true,
          ),
        ),
    );
    final useCaseClass = Class(
      (c) => c
        ..name = className
        ..extend = baseClass
        ..fields.add(repoField)
        ..constructors.add(ctor)
        ..methods.add(executeMethod),
    );
    final library = const SpecLibrary().library(
      specs: [useCaseClass],
      directives: imports.map(Directive.import),
    );
    final content = const SpecLibrary().emitLibrary(library);

    return _writeOrAppend(
      config: config,
      filePath: filePath,
      className: className,
      executeMethodSource: executeMethod
          .accept(DartEmitter(orderDirectives: true, useNullSafetySyntax: true))
          .toString(),
      content: content,
    );
  }

  Future<GeneratedFile> _writeOrAppend({
    required GeneratorConfig config,
    required String filePath,
    required String className,
    required String executeMethodSource,
    required String content,
  }) async {
    if (config.revert) {
      return FileUtils.deleteFile(
        filePath,
        'usecase',
        dryRun: options.dryRun,
        verbose: options.verbose,
      );
    }

    if (File(filePath).existsSync()) {
      if (options.force) {
        return FileUtils.writeFile(
          filePath,
          content,
          'usecase',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
        );
      }

      var updatedSource = await File(filePath).readAsString();
      final result = appendExecutor.execute(
        AppendRequest.method(
          source: updatedSource,
          className: className,
          memberSource: executeMethodSource,
        ),
      );
      if (!result.changed) {
        return GeneratedFile(
          path: filePath,
          type: 'usecase',
          action: 'skipped',
          content: updatedSource,
        );
      }
      return FileUtils.writeFile(
        filePath,
        result.source,
        'usecase',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
      );
    }

    return FileUtils.writeFile(
      filePath,
      content,
      'usecase',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
    );
  }

  Reference _parseType(String raw, String entityName) {
    if (raw.startsWith('Partial<')) {
      return TypeReference(
        (tr) => tr
          ..symbol = 'Partial'
          ..types.add(refer(entityName)),
      );
    }
    return refer(raw);
  }
}
