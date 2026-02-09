import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../builders/usecase_class_builder.dart';
import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';

class EntityUseCaseGenerator {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final UseCaseClassBuilder classBuilder;
  final AppendExecutor appendExecutor;

  EntityUseCaseGenerator({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    UseCaseClassBuilder? classBuilder,
    AppendExecutor? appendExecutor,
  })  : classBuilder = classBuilder ?? const UseCaseClassBuilder(),
        appendExecutor = appendExecutor ?? AppendExecutor();

  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final files = <GeneratedFile>[];
    for (final method in config.methods) {
      files.add(await _generateForMethod(config, method));
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
    String baseClass;
    String paramsType;
    String returnType;
    String executeBody;
    bool isStream = false;
    bool isCompletable = false;
    bool needsEntityImport = true;

    switch (method) {
      case 'get':
        className = 'Get${entityName}UseCase';
        if (config.queryFieldType == 'NoParams') {
          baseClass = 'UseCase<$entityName, NoParams>';
          paramsType = 'NoParams';
          executeBody = 'return _repository.get(const QueryParams());';
        } else {
          baseClass = 'UseCase<$entityName, QueryParams<$entityName>>';
          paramsType = 'QueryParams<$entityName>';
          executeBody = 'return _repository.get(params);';
        }
        returnType = entityName;
        break;
      case 'getList':
        className = 'Get${entityName}ListUseCase';
        baseClass = 'UseCase<List<$entityName>, ListQueryParams<$entityName>>';
        paramsType = 'ListQueryParams<$entityName>';
        returnType = 'List<$entityName>';
        executeBody = 'return _repository.getList(params);';
        break;
      case 'create':
        className = 'Create${entityName}UseCase';
        baseClass = 'UseCase<$entityName, $entityName>';
        paramsType = entityName;
        returnType = entityName;
        executeBody = 'return _repository.create(params);';
        break;
      case 'update':
        className = 'Update${entityName}UseCase';
        final dataType = config.useZorphy
            ? '${entityName}Patch'
            : 'Partial<$entityName>';
        baseClass =
            'UseCase<$entityName, UpdateParams<${config.idType}, $dataType>>';
        paramsType = 'UpdateParams<${config.idType}, $dataType>';
        returnType = entityName;
        executeBody = 'return _repository.update(params);';
        break;
      case 'delete':
        className = 'Delete${entityName}UseCase';
        baseClass = 'CompletableUseCase<DeleteParams<${config.idType}>>';
        paramsType = 'DeleteParams<${config.idType}>';
        returnType = 'void';
        executeBody = 'return _repository.delete(params);';
        isCompletable = true;
        needsEntityImport = false;
        break;
      case 'watch':
        className = 'Watch${entityName}UseCase';
        if (config.queryFieldType == 'NoParams') {
          baseClass = 'StreamUseCase<$entityName, NoParams>';
          paramsType = 'NoParams';
          executeBody = 'return _repository.watch(const QueryParams());';
        } else {
          baseClass = 'StreamUseCase<$entityName, QueryParams<$entityName>>';
          paramsType = 'QueryParams<$entityName>';
          executeBody = 'return _repository.watch(params);';
        }
        returnType = entityName;
        isStream = true;
        break;
      case 'watchList':
        className = 'Watch${entityName}ListUseCase';
        baseClass =
            'StreamUseCase<List<$entityName>, ListQueryParams<$entityName>>';
        paramsType = 'ListQueryParams<$entityName>';
        returnType = 'List<$entityName>';
        executeBody = 'return _repository.watchList(params);';
        isStream = true;
        break;
      default:
        throw ArgumentError('Unknown method: $method');
    }

    final fileSnake = StringUtils.camelToSnake(
      className.replaceAll('UseCase', ''),
    );
    final fileName = '${fileSnake}_usecase.dart';
    final usecaseDirPath =
        path.join(outputDir, 'domain', 'usecases', entitySnake);
    final filePath = path.join(usecaseDirPath, fileName);

    final imports = <String>['package:zuraffa/zuraffa.dart'];
    if (needsEntityImport) {
      imports.add('../../entities/$entitySnake/$entitySnake.dart');
    }
    imports.add(
      '../../repositories/${StringUtils.camelToSnake(repoName.replaceAll('Repository', ''))}_repository.dart',
    );

    final executeMethod = _buildExecuteMethod(
      isStream: isStream,
      isCompletable: isCompletable,
      paramsType: paramsType,
      returnType: returnType,
      executeBody: executeBody,
    );

    final spec = UseCaseClassSpec(
      className: className,
      baseClass: baseClass,
      fields: [
        Field(
          (b) => b
            ..name = '_repository'
            ..type = refer(repoName)
            ..modifier = FieldModifier.final$,
        ),
      ],
      constructors: [
        Constructor(
          (b) => b
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = '_repository'
                  ..toThis = true,
              ),
            ),
        ),
      ],
      methods: [executeMethod],
      imports: imports,
    );

    final content = classBuilder.build(spec);
    return _writeOrAppend(
      config: config,
      filePath: filePath,
      className: className,
      executeMethodSource: _methodSourceForAppend(
        executeMethod,
        isStream: isStream,
        isCompletable: isCompletable,
        paramsType: paramsType,
        returnType: returnType,
        executeBody: executeBody,
      ),
      content: content,
    );
  }

  Method _buildExecuteMethod({
    required bool isStream,
    required bool isCompletable,
    required String paramsType,
    required String returnType,
    required String executeBody,
  }) {
    final returnTypeRef = isStream
        ? 'Stream<$returnType>'
        : isCompletable
            ? 'Future<void>'
            : 'Future<$returnType>';

    final body = StringBuffer()
      ..writeln('cancelToken?.throwIfCancelled();')
      ..writeln(executeBody);

    return Method(
      (b) => b
        ..name = 'execute'
        ..returns = refer(returnTypeRef)
        ..modifier = isStream ? null : MethodModifier.async
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        )
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'cancelToken'
              ..type = refer('CancelToken?'),
          ),
        )
        ..annotations.add(CodeExpression(Code('override')))
        ..body = Code(body.toString()),
    );
  }

  String _methodSourceForAppend(
    Method method, {
    required bool isStream,
    required bool isCompletable,
    required String paramsType,
    required String returnType,
    required String executeBody,
  }) {
    final returnTypeRef = isStream
        ? 'Stream<$returnType>'
        : isCompletable
            ? 'Future<void>'
            : 'Future<$returnType>';
    final buffer = StringBuffer()
      ..writeln('@override')
      ..write('$returnTypeRef execute($paramsType params, CancelToken? cancelToken)');
    if (!isStream) {
      buffer.write(' async');
    }
    buffer.writeln(' {');
    buffer.writeln('  cancelToken?.throwIfCancelled();');
    buffer.writeln('  $executeBody');
    buffer.writeln('}');
    return buffer.toString();
  }

  Future<GeneratedFile> _writeOrAppend({
    required GeneratorConfig config,
    required String filePath,
    required String className,
    required String executeMethodSource,
    required String content,
  }) async {
    if (config.appendToExisting && File(filePath).existsSync()) {
      final existing = await File(filePath).readAsString();
      final result = appendExecutor.execute(
        AppendRequest.method(
          source: existing,
          className: className,
          memberSource: executeMethodSource,
        ),
      );
      if (!result.changed) {
        return GeneratedFile(
          path: filePath,
          type: 'usecase',
          action: 'skipped',
          content: result.source,
        );
      }
      return FileUtils.writeFile(
        filePath,
        result.source,
        'usecase',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
      );
    }

    return FileUtils.writeFile(
      filePath,
      content,
      'usecase',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }
}
