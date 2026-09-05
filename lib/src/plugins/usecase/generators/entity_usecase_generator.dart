import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/builder/patterns/common_patterns.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/source_interface_guard.dart';
import '../../../utils/stale_usecase_test_cleaner.dart';
import '../../../utils/string_utils.dart';
import '../usecase_verdicts.dart';

/// Generates entity-based use cases for the domain layer.
class EntityUseCaseGenerator {
  final String outputDir;
  final GeneratorOptions options;
  final AppendExecutor appendExecutor;
  final FileSystem fileSystem;

  EntityUseCaseGenerator({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.appendExecutor = const AppendExecutor(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create();

  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final report = await generateWithVerdicts(config);
    return report.files;
  }

  /// Spec #972 API: the same generation as [generate], plus per-method
  /// verdicts and the same-plan interface expectation callback.
  ///
  /// [onInterfaceExpectation] fires exactly once when the source
  /// interface was absent at generation time (the fail-open case) and at
  /// least one method survived — the caller records it in the plan so
  /// the `zfa make` post-pass can verify the responsible plugin declared
  /// the methods.
  Future<UsecaseGenerationReport> generateWithVerdicts(
    GeneratorConfig config, {
    void Function(UseCaseInterfaceExpectation expectation)?
    onInterfaceExpectation,
    bool quiet = false,
  }) async {
    final files = <GeneratedFile>[];
    final verdicts = <MethodVerdict>[];
    final guardReasonCodes = <String, String>{};
    final validMethods = [
      'get',
      'getList',
      'list',
      'create',
      'update',
      'toggle',
      'delete',
      'watch',
      'watchList',
    ];

    // Issue #921: only request use cases whose action methods exist on the
    // entity's repository/service interface. The guard fails open when the
    // interface file does not exist yet (same-plan generation) or cannot be
    // positively parsed.
    final requestedMethods = <String>[];
    for (final method in config.methods) {
      if (!validMethods.contains(method)) {
        verdicts.add(
          MethodVerdict(
            name: method,
            action: MethodVerdict.actionSkipped,
            reason: MethodVerdict.reasonUnknownMethod,
          ),
        );
        if (config.verbose) {
          print('  Skip unknown method: $method');
        }
        continue;
      }
      requestedMethods.add(method);
    }
    final guard = await const SourceInterfaceGuard().evaluate(
      config,
      methods: requestedMethods,
      fileSystem: fileSystem,
    );
    for (final drop in guard.dropped) {
      if (!quiet) {
        // Legacy parity: the skip notice is the only human explanation of
        // a dropped usecase, so it keeps printing outside --json mode.
        print(drop.notice);
      }
      guardReasonCodes[drop.method] = drop.code;
      verdicts.add(
        MethodVerdict(
          name: drop.method,
          action: MethodVerdict.actionSkipped,
          reason: drop.code,
        ),
      );
    }

    // Spec #972 FR-4: the interface was absent — record what this run
    // assumes the same plan will declare.
    if (guard.interfaceAbsent &&
        guard.kept.isNotEmpty &&
        guard.className != null &&
        guard.interfacePath != null) {
      onInterfaceExpectation?.call(
        UseCaseInterfaceExpectation(
          entity: config.name,
          interfacePath: guard.interfacePath!,
          className: guard.className!,
          methods: List.unmodifiable(guard.kept),
          viaService: config.hasService,
        ),
      );
    }

    final methodToFile = <String, GeneratedFile>{};
    for (final method in guard.kept) {
      final file = await _generateForMethod(config, method);
      files.add(file);
      methodToFile[method] = file;
    }
    for (final method in guard.kept) {
      final file = methodToFile[method];
      verdicts.add(_verdictForFile(method, file, revert: config.revert));
    }

    // Bug #989: every requested-but-rejected use case leaves pre-existing
    // test files importing a use case file that will never be regenerated;
    // those files break the suite at load time. When #921 rejects anything,
    // sweep the test suite for imports of non-existent use case files and
    // remove the stale surface. The rejection semantics themselves are
    // unchanged — this only cleans up the debris the rejection leaves.
    final rejectedMethods = requestedMethods
        .where((method) => !guard.kept.contains(method))
        .toList(growable: false);

    if (rejectedMethods.isNotEmpty && !config.revert) {
      files.addAll(
        await StaleUsecaseTestCleaner(
          outputDir: outputDir,
          options: options,
          fileSystem: fileSystem,
        ).clean(),
      );
    }

    if (config.revert && config.methods.isEmpty) {
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
        if (await fileSystem.exists(filePath)) {
          final file = await FileUtils.deleteFile(
            filePath,
            'usecase',
            dryRun: options.dryRun,
            verbose: options.verbose,
            fileSystem: fileSystem,
          );
          files.add(file);
          verdicts.add(
            _verdictForFile(
              _methodFromCanonicalFile(fileName),
              file,
              revert: true,
            ),
          );
        }
      }
    }
    // Request-order verdicts (stable machine contract).
    final ordered = <MethodVerdict>[];
    final requestedOrder = [...config.methods];
    for (final method in requestedOrder) {
      final match = verdicts.where((v) => v.name == method).toList();
      ordered.addAll(match);
      verdicts.removeWhere((v) => v.name == method);
    }
    // Canonical-file deletions (revert with an empty method set) have no
    // requested order — append them after the requested ones.
    ordered.addAll(verdicts);

    return UsecaseGenerationReport(
      files: files,
      verdicts: ordered,
      interfaceAbsent: guard.interfaceAbsent,
      guardReasonCodes: guardReasonCodes,
    );
  }

  /// Maps a [GeneratedFile] action to the spec #972 per-method verdict.
  MethodVerdict _verdictForFile(
    String method,
    GeneratedFile? file, {
    required bool revert,
  }) {
    if (file == null) {
      return MethodVerdict(
        name: method,
        action: MethodVerdict.actionSkipped,
        reason: MethodVerdict.reasonUnknownMethod,
      );
    }
    switch (file.action) {
      case 'created':
        return MethodVerdict(name: method, action: MethodVerdict.actionCreated);
      case 'overwritten':
      case 'updated':
        return MethodVerdict(
          name: method,
          action: MethodVerdict.actionAppended,
        );
      case 'deleted':
      case 'reverted':
        return MethodVerdict(name: method, action: MethodVerdict.actionDeleted);
      case 'skipped':
      default:
        return MethodVerdict(
          name: method,
          action: MethodVerdict.actionSkipped,
          reason: revert
              ? MethodVerdict.reasonNothingToRevert
              : MethodVerdict.reasonAlreadyPresent,
        );
    }
  }

  /// Recovers the method name from a canonical revert file name
  /// (`get_product_usecase.dart` → `get`).
  String _methodFromCanonicalFile(String fileName) {
    final stem = fileName.replaceAll('_usecase.dart', '');
    final parts = stem.split('_');
    // <verb>_<entity...> — the verb is the first segment; watch_list and
    // get_list collapse to their generating request names.
    final verb = parts.first;
    if (parts.length >= 3 && parts[parts.length - 2] == 'list') {
      return '${parts.first}List';
    }
    return verb;
  }

  Future<GeneratedFile> _generateForMethod(
    GeneratorConfig config,
    String method,
  ) async {
    final entityName = config.name;
    final hasService = config.hasService;
    final sourceName = hasService
        ? config.effectiveService!
        : (config.effectiveRepos.isNotEmpty
              ? config.effectiveRepos.first
              : '${entityName}Repository');
    final sourceField = hasService ? '_service' : '_repository';

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
            sourceField,
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
            sourceField,
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
          sourceField,
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
          sourceField,
        ).property('create').call([refer('params')]);
        break;
      case 'update':
        className = 'Update${entityName}UseCase';
        final dataType = config.useZorphy
            ? '${entityName}Patch'
            : 'Partial<$entityName>';
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
                    _parseType(dataType),
                  ]),
              ),
            ]),
        );
        paramsType = TypeReference(
          (tr) => tr
            ..symbol = 'UpdateParams'
            ..types.addAll([refer(config.idFieldType), _parseType(dataType)]),
        );
        returnType = refer(entityName);
        executeExpression = refer(
          sourceField,
        ).property('update').call([refer('params')]);
        break;
      case 'toggle':
        className = 'Toggle${entityName}UseCase';
        final fieldEnum = 'Field<$entityName, dynamic>';
        baseClass = TypeReference(
          (t) => t
            ..symbol = 'UseCase'
            ..types.addAll([
              refer(entityName),
              TypeReference(
                (tr) => tr
                  ..symbol = 'ToggleParams'
                  ..types.addAll([refer(config.idFieldType), refer(fieldEnum)]),
              ),
            ]),
        );
        paramsType = TypeReference(
          (tr) => tr
            ..symbol = 'ToggleParams'
            ..types.addAll([refer(config.idFieldType), refer(fieldEnum)]),
        );
        returnType = refer(entityName);
        executeExpression = refer(
          sourceField,
        ).property('toggle').call([refer('params')]);
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
          sourceField,
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
            sourceField,
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
            sourceField,
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
          sourceField,
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
    // #321: always run the import resolver with at least the id/query
    // field types so an enum-typed id (e.g. DeleteParams<SomeEnum>,
    // ToggleParams<SomeEnum, Field>, UpdateParams<SomeEnum, Patch>) gets
    // the enum barrel import emitted. Previously the `delete` usecase
    // (needsEntityImport = false) skipped this block entirely, leaving
    // `DeleteParams<ChatMessageRole>` without the enum import.
    //
    // When needsEntityImport is true (get/getList/create/update/toggle/
    // watch/watchList), also include the paramsType and returnType so
    // entity/patch types referenced in the signature get imported too.
    final sigTypes = <String>[config.idFieldType, config.queryFieldType];
    if (needsEntityImport) {
      sigTypes.add(paramsType.accept(DartEmitter()).toString());
      sigTypes.add(returnType.accept(DartEmitter()).toString());
    }
    final entityImports = CommonPatterns.entityImports(
      sigTypes,
      config,
      depth: 3,
      includeDomain: false,
      fileSystem: fileSystem,
    );
    imports.addAll(entityImports);

    // Issue #942: the use case imports the entity file(s) AND the
    // framework barrel unprefixed — an entity whose name matches a
    // zuraffa core export (e.g. `Credentials`) makes this file fail with
    // `ambiguous_import` errors. The generator knows the locally-imported
    // entity symbols (the same `sigTypes` the entity imports were
    // resolved from), so the barrel import hides exactly those symbols
    // and the entity's own definitions win resolution. With no
    // locally-imported entity types the hide list stays empty and the
    // import is emitted unchanged.
    final barrelHide = CommonPatterns.barrelHideNamesForTypes(sigTypes);

    if (hasService) {
      final serviceSnake = StringUtils.camelToSnake(
        sourceName.replaceAll('Service', ''),
      );
      final servicePath =
          '../../services/${config.effectiveDomain}/${serviceSnake}_service.dart';
      imports.add(servicePath);
    } else {
      final repoPath =
          '../../repositories/${StringUtils.camelToSnake(sourceName.replaceAll('Repository', ''))}_repository.dart';
      imports.add(repoPath);
    }

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

    final sourceFieldRef = Field(
      (f) => f
        ..modifier = FieldModifier.final$
        ..type = refer(sourceName)
        ..name = sourceField,
    );
    final ctor = Constructor(
      (c) => c
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = sourceField
              ..toThis = true,
          ),
        ),
    );
    final useCaseClass = Class(
      (c) => c
        ..name = className
        ..extend = baseClass
        ..fields.add(sourceFieldRef)
        ..constructors.add(ctor)
        ..methods.add(executeMethod),
    );
    final library = const SpecLibrary().library(
      specs: [useCaseClass],
      directives: imports.map(
        (uri) => uri == 'package:zuraffa/zuraffa.dart' && barrelHide.isNotEmpty
            ? Directive.import(uri, hide: barrelHide)
            : Directive.import(uri),
      ),
    );
    final content = const SpecLibrary().emitLibrary(
      library,
      leadingComment: '// Generated by zfa for: ${config.name}',
    );

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
      return FileUtils.writeFile(
        filePath,
        content,
        'usecase',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
        revert: true,
        skipRevertIfExisted: true,
        fileSystem: fileSystem,
      );
    }

    if (await fileSystem.exists(filePath)) {
      if (options.force) {
        return FileUtils.writeFile(
          filePath,
          content,
          'usecase',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          fileSystem: fileSystem,
        );
      }

      var updatedSource = await fileSystem.read(filePath);
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
        fileSystem: fileSystem,
      );
    }

    return FileUtils.writeFile(
      filePath,
      content,
      'usecase',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      fileSystem: fileSystem,
    );
  }

  Reference _parseType(String raw) {
    return refer(raw);
  }
}
