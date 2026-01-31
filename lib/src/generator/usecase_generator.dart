import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/generator_config.dart';
import '../models/generated_file.dart';
import '../utils/file_utils.dart';
import '../utils/string_utils.dart';

class UseCaseInfo {
  final String className;
  final String fieldName;
  final String presenterMethod;

  UseCaseInfo({
    required this.className,
    required this.fieldName,
    required this.presenterMethod,
  });
}

class UseCaseGenerator {
  final GeneratorConfig config;
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  UseCaseGenerator({
    required this.config,
    required this.outputDir,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
  });

  Future<GeneratedFile> generateForMethod(String method) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final repoName = config.effectiveRepos.first;
    String relativePath = '../';

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
        baseClass = 'UseCase<$entityName, QueryParams<${config.queryFieldType}>>';
        paramsType = 'QueryParams<${config.queryFieldType}>';
        returnType = entityName;
        executeBody = 'return _repository.get(params.query);';
        break;
      case 'getList':
        className = 'Get${entityName}ListUseCase';
        baseClass = 'UseCase<List<$entityName>, ListQueryParams>';
        paramsType = 'ListQueryParams';
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
        final dataType = config.useMorphy ? '${entityName}Patch' : 'Partial<$entityName>';
        baseClass = 'UseCase<$entityName, UpdateParams<$dataType>>';
        paramsType = 'UpdateParams<$dataType>';
        returnType = entityName;
        
        if (config.useMorphy) {
          executeBody = 'return _repository.update(params);';
        } else {
          final fields = _extractEntityFields(entitySnake);
          final validationCall = fields.isNotEmpty
              ? 'params.validate([${fields.map((f) => "'$f'").join(', ')}]);'
              : '// params.validate([]); // TODO: List valid fields for partial update';
              
          executeBody = '''$validationCall
    return _repository.update(params);''';
        }
        break;
      case 'delete':
        className = 'Delete${entityName}UseCase';
        baseClass = 'CompletableUseCase<DeleteParams<$entityName>>';
        paramsType = 'DeleteParams<$entityName>';
        returnType = 'void';
        executeBody = 'return _repository.delete(params);';
        isCompletable = true;
        break;
      case 'watch':
        className = 'Watch${entityName}UseCase';
        baseClass = 'StreamUseCase<$entityName, QueryParams<${config.queryFieldType}>>';
        paramsType = 'QueryParams<${config.queryFieldType}>';
        returnType = entityName;
        executeBody = 'return _repository.watch(params.query);';
        isStream = true;
        break;
      case 'watchList':
        className = 'Watch${entityName}ListUseCase';
        baseClass = 'StreamUseCase<List<$entityName>, ListQueryParams>';
        paramsType = 'ListQueryParams';
        returnType = 'List<$entityName>';
        executeBody = 'return _repository.watchList(params);';
        isStream = true;
        break;
      default:
        throw ArgumentError('Unknown method: $method');
    }

    final paramName = 'params';
    final fileSnake =
        StringUtils.camelToSnake(className.replaceAll('UseCase', ''));
    final fileName = '${fileSnake}_usecase.dart';

    final usecasePathParts = <String>[
      outputDir,
      'domain',
      'usecases',
    ];
    if (config.subdirectory != null && config.subdirectory!.isNotEmpty) {
      usecasePathParts.add(config.subdirectory!);
      relativePath += '../';
    }
    usecasePathParts.add(entitySnake);
    final usecaseDirPath = path.joinAll(usecasePathParts);
    final filePath = path.join(usecaseDirPath, fileName);

    final imports = <String>[
      "import 'package:zuraffa/zuraffa.dart';",
    ];
    if (needsEntityImport) {
      final entityPath =
          '$relativePath../entities/$entitySnake/$entitySnake.dart';
      imports.add("import '$entityPath';");
    }
    final repoPath =
        '$relativePath../repositories/${StringUtils.camelToSnake(repoName.replaceAll('Repository', ''))}_repository.dart';
    imports.add("import '$repoPath';");

    String executeMethod;
    if (isStream) {
      executeMethod = '''
  @override
  Stream<$returnType> execute($paramsType $paramName, CancelToken? cancelToken) {
    cancelToken?.throwIfCancelled();
    $executeBody
  }''';
    } else if (isCompletable) {
      executeMethod = '''
  @override
  Future<void> execute($paramsType $paramName, CancelToken? cancelToken) async {
    cancelToken?.throwIfCancelled();
    $executeBody
  }''';
    } else {
      executeMethod = '''
  @override
  Future<$returnType> execute($paramsType $paramName, CancelToken? cancelToken) async {
    cancelToken?.throwIfCancelled();
    $executeBody
  }''';
    }

    final content = '''
// Generated by zfa

${imports.join('\n')}

class $className extends $baseClass {
  final $repoName _repository;

  $className(this._repository);

$executeMethod
}
''';

    return FileUtils.writeFile(
      filePath,
      content,
      'usecase',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> generateCustom() async {
    final className = '${config.name}UseCase';
    final classSnake = StringUtils.camelToSnake(config.name);
    final fileName = '${classSnake}_usecase.dart';

    final usecasePathParts = <String>[outputDir, 'domain', 'usecases'];
    if (config.subdirectory != null && config.subdirectory!.isNotEmpty) {
      usecasePathParts.add(config.subdirectory!);
    }
    final usecaseDirPath = path.joinAll(usecasePathParts);
    final filePath = path.join(usecaseDirPath, fileName);

    final paramsType = config.paramsType ?? 'NoParams';
    final returnsType = config.returnsType ?? 'void';

    String baseClass;
    switch (config.useCaseType) {
      case 'stream':
        baseClass = 'StreamUseCase<$returnsType, $paramsType>';
        break;
      case 'background':
        baseClass = 'BackgroundUseCase<$returnsType, $paramsType>';
        break;
      case 'completable':
        baseClass = 'CompletableUseCase<$paramsType>';
        break;
      default:
        baseClass = 'UseCase<$returnsType, $paramsType>';
    }

    final repoImports = <String>[];
    final repoFields = <String>[];
    final repoParams = <String>[];

    for (final repo in config.effectiveRepos) {
      final repoSnake =
          StringUtils.camelToSnake(repo.replaceAll('Repository', ''));
      final repoPath =
          config.subdirectory != null && config.subdirectory!.isNotEmpty
              ? '../../repositories/${repoSnake}_repository.dart'
              : '../repositories/${repoSnake}_repository.dart';
      repoImports.add("import '$repoPath';");
      repoFields.add('  final $repo _${StringUtils.pascalToCamel(repo)};');
      repoParams.add('this._${StringUtils.pascalToCamel(repo)}');
    }

    // Auto-import potential entity types from params and returns
    final entityImports = _getPotentialEntityImports([paramsType, returnsType]);
    for (final entityImport in entityImports) {
      final entitySnake = StringUtils.camelToSnake(entityImport);
      final entityFolder = StringUtils.snakeToPath(entitySnake);

      final entityPath =
          config.subdirectory != null && config.subdirectory!.isNotEmpty
              ? '../../entities/$entityFolder/$entitySnake.dart'
              : '../entities/$entityFolder/$entitySnake.dart';
      repoImports.add("import '$entityPath';");
    }

    String executeMethod;
    if (config.useCaseType == 'stream') {
      executeMethod = '''
  @override
  Stream<$returnsType> execute($paramsType params, CancelToken? cancelToken) {
    throw UnimplementedError();
  }''';
    } else if (config.useCaseType == 'background') {
      executeMethod = '''
  @override
  BackgroundTask<$paramsType> buildTask() => _process;

  static void _process(BackgroundTaskContext<$paramsType> context) {
    try {
      final params = context.params;
      context.sendDone();
    } catch (e, stackTrace) {
      context.sendError(e, stackTrace);
    }
  }''';
    } else {
      executeMethod = '''
  @override
  Future<$returnsType> execute($paramsType params, CancelToken? cancelToken) async {
    cancelToken?.throwIfCancelled();
    throw UnimplementedError();
  }''';
    }

    final content = '''
// Generated by zfa
// zfa generate ${config.name} --repos=${config.repos.join(',')} --params=$paramsType --returns=$returnsType --type=${config.useCaseType}

import 'package:zuraffa/zuraffa.dart';
${repoImports.join('\n')}

class $className extends $baseClass {
${repoFields.join('\n')}

  $className(${repoParams.join(', ')});

$executeMethod
}
''';

    return FileUtils.writeFile(
      filePath,
      content,
      'usecase',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  UseCaseInfo getUseCaseInfo(
      String method, String entityName, String entityCamel) {
    switch (method) {
      case 'get':
        return UseCaseInfo(
          className: 'Get${entityName}UseCase',
          fieldName: 'get$entityName',
          presenterMethod:
              '''  Future<Result<$entityName, AppFailure>> get$entityName(${config.queryFieldType} ${config.queryField}) {
    return _get$entityName.call(QueryParams(${config.queryField}));
  }''',
        );
      case 'getList':
        return UseCaseInfo(
          className: 'Get${entityName}ListUseCase',
          fieldName: 'get${entityName}List',
          presenterMethod:
              '''  Future<Result<List<$entityName>, AppFailure>> get${entityName}List([ListQueryParams params = const ListQueryParams()]) {
    return _get${entityName}List.call(params);
  }''',
        );
      case 'create':
        return UseCaseInfo(
          className: 'Create${entityName}UseCase',
          fieldName: 'create$entityName',
          presenterMethod:
              '''  Future<Result<$entityName, AppFailure>> create$entityName($entityName $entityCamel) {
    return _create$entityName.call($entityCamel);
  }''',
        );
      case 'update':
        final updateDataType = config.useMorphy ? '${entityName}Patch' : 'Partial<$entityName>';
        return UseCaseInfo(
          className: 'Update${entityName}UseCase',
          fieldName: 'update$entityName',
          presenterMethod:
              '''  Future<Result<$entityName, AppFailure>> update$entityName(${config.idType} ${config.idField}, $updateDataType data) {
    return _update$entityName.call(UpdateParams(id: ${config.idField}, data: data));
  }''',
        );
      case 'delete':
        return UseCaseInfo(
          className: 'Delete${entityName}UseCase',
          fieldName: 'delete$entityName',
          presenterMethod:
              '''  Future<Result<void, AppFailure>> delete$entityName(${config.idType} ${config.idField}) {
    return _delete$entityName.call(DeleteParams(${config.idField}));
  }''',
        );
      case 'watch':
        return UseCaseInfo(
          className: 'Watch${entityName}UseCase',
          fieldName: 'watch$entityName',
          presenterMethod:
              '''  Stream<Result<$entityName, AppFailure>> watch$entityName(${config.queryFieldType}? ${config.queryField}) {
    return _watch$entityName.call(QueryParams(${config.queryField}));
  }''',
        );
      case 'watchList':
        return UseCaseInfo(
          className: 'Watch${entityName}ListUseCase',
          fieldName: 'watch${entityName}List',
          presenterMethod:
              '''  Stream<Result<List<$entityName>, AppFailure>> watch${entityName}List([ListQueryParams params = const ListQueryParams()]) {
    return _watch${entityName}List.call(params);
  }''',
        );
      default:
        throw ArgumentError('Unknown method: $method');
    }
  }

  List<String> _extractEntityFields(String entitySnake) {
    try {
      // Try to find the entity file in common Clean Architecture locations
      final possiblePaths = [
        // Standard: lib/src/domain/entities/todo/todo.dart (folder per entity)
        path.join(outputDir, 'domain', 'entities', entitySnake, '$entitySnake.dart'),
        // Flat: lib/src/domain/entities/todo.dart
        path.join(outputDir, 'domain', 'entities', '$entitySnake.dart'),
      ];

      File? file;
      for (final p in possiblePaths) {
        final f = File(p);
        if (f.existsSync()) {
          file = f;
          break;
        }
      }

      if (file == null) {
        if (verbose) {
          print('  ℹ Entity file for $entitySnake not found, skipping auto-validation');
        }
        return [];
      }

      final content = file.readAsStringSync();
      // Regex to find fields (usually final or non-static members)
      // Matches both 'final int id;' and 'String? name;'
      // but avoids methods and static members.
      final regex = RegExp(r'^\s+(?:final\s+)?(?:[\w<>,?!\s]+)\s+(\w+)\s*;', multiLine: true);
      final matches = regex.allMatches(content);

      final fields = matches.map((m) => m.group(1)!).where((f) => f != 'hashCode').toList();
      
      if (verbose && fields.isNotEmpty) {
        print('  ✓ Automatically extracted fields for validation: ${fields.join(', ')}');
      }
      
      return fields;
    } catch (e) {
      if (verbose) print('  ⚠️ Error extracting fields: $e');
      return [];
    }
  }
}

Set<String> _getPotentialEntityImports(List<String> types) {
  final entityNames = <String>{};

  for (final type in types) {
    final regex = RegExp(r'[A-Z][a-zA-Z0-9_]*');
    final matches = regex.allMatches(type);
    for (final match in matches) {
      final name = match.group(0);
      if (name != null &&
          name != 'List' &&
          name != 'Map' &&
          name != 'Set' &&
          name != 'NoParams' &&
          !RegExp(r'^(int|double|bool|String|void|dynamic)$').hasMatch(name)) {
        entityNames.add(name);
      }
    }
  }

  return entityNames;
}
