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
        baseClass = 'UseCase<$entityName, ${config.idType}>';
        paramsType = config.idType;
        returnType = entityName;
        executeBody = 'return _repository.get(id);';
        break;
      case 'getList':
        className = 'Get${entityName}ListUseCase';
        baseClass = 'UseCase<List<$entityName>, NoParams>';
        paramsType = 'NoParams';
        returnType = 'List<$entityName>';
        executeBody = 'return _repository.getList();';
        break;
      case 'create':
        className = 'Create${entityName}UseCase';
        baseClass = 'UseCase<$entityName, $entityName>';
        paramsType = entityName;
        returnType = entityName;
        executeBody = 'return _repository.create($entityCamel);';
        break;
      case 'update':
        className = 'Update${entityName}UseCase';
        baseClass = 'UseCase<$entityName, $entityName>';
        paramsType = entityName;
        returnType = entityName;
        executeBody = 'return _repository.update($entityCamel);';
        break;
      case 'delete':
        className = 'Delete${entityName}UseCase';
        baseClass = 'CompletableUseCase<${config.idType}>';
        paramsType = config.idType;
        returnType = 'void';
        executeBody = 'return _repository.delete(id);';
        isCompletable = true;
        needsEntityImport = false;
        break;
      case 'watch':
        className = 'Watch${entityName}UseCase';
        baseClass = 'StreamUseCase<$entityName, ${config.idType}?>';
        paramsType = '${config.idType}?';
        returnType = entityName;
        executeBody = 'return _repository.watch(id);';
        isStream = true;
        break;
      case 'watchList':
        className = 'Watch${entityName}ListUseCase';
        baseClass = 'StreamUseCase<List<$entityName>, NoParams>';
        paramsType = 'NoParams';
        returnType = 'List<$entityName>';
        executeBody = 'return _repository.watchList();';
        isStream = true;
        break;
      default:
        throw ArgumentError('Unknown method: $method');
    }

    final paramName = FileUtils.getParamName(method, entityCamel);
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
    }
    usecasePathParts.add(entitySnake);
    final usecaseDirPath = path.joinAll(usecasePathParts);
    final filePath = path.join(usecaseDirPath, fileName);

    final imports = <String>[
      "import 'package:zuraffa/zuraffa.dart';",
    ];
    if (needsEntityImport) {
      final entityPath =
          config.subdirectory != null && config.subdirectory!.isNotEmpty
              ? '../../entities/$entitySnake/$entitySnake.dart'
              : '../entities/$entitySnake/$entitySnake.dart';
      imports.add("import '$entityPath';");
    }
    final repoPath = config.subdirectory != null &&
            config.subdirectory!.isNotEmpty
        ? '../../repositories/${StringUtils.camelToSnake(repoName.replaceAll('Repository', ''))}_repository.dart'
        : '../repositories/${StringUtils.camelToSnake(repoName.replaceAll('Repository', ''))}_repository.dart';
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
      final entityPath =
          config.subdirectory != null && config.subdirectory!.isNotEmpty
              ? '../../entities/$entitySnake/$entitySnake.dart'
              : '../entities/$entitySnake/$entitySnake.dart';
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
              '''  Future<Result<$entityName, AppFailure>> get$entityName(String id) {
    return execute(_get$entityName, id);
  }''',
        );
      case 'getList':
        return UseCaseInfo(
          className: 'Get${entityName}ListUseCase',
          fieldName: 'get${entityName}List',
          presenterMethod:
              '''  Future<Result<List<$entityName>, AppFailure>> get${entityName}List() {
    return execute(_get${entityName}List, const NoParams());
  }''',
        );
      case 'create':
        return UseCaseInfo(
          className: 'Create${entityName}UseCase',
          fieldName: 'create$entityName',
          presenterMethod:
              '''  Future<Result<$entityName, AppFailure>> create$entityName($entityName $entityCamel) {
    return execute(_create$entityName, $entityCamel);
  }''',
        );
      case 'update':
        return UseCaseInfo(
          className: 'Update${entityName}UseCase',
          fieldName: 'update$entityName',
          presenterMethod:
              '''  Future<Result<$entityName, AppFailure>> update$entityName($entityName $entityCamel) {
    return execute(_update$entityName, $entityCamel);
  }''',
        );
      case 'delete':
        return UseCaseInfo(
          className: 'Delete${entityName}UseCase',
          fieldName: 'delete$entityName',
          presenterMethod:
              '''  Future<Result<void, AppFailure>> delete$entityName(String id) {
    return execute(_delete$entityName, id);
  }''',
        );
      case 'watch':
        return UseCaseInfo(
          className: 'Watch${entityName}UseCase',
          fieldName: 'watch$entityName',
          presenterMethod:
              '''  Stream<Result<$entityName, AppFailure>> watch$entityName(String? id) {
    return executeStream(_watch$entityName, id);
  }''',
        );
      case 'watchList':
        return UseCaseInfo(
          className: 'Watch${entityName}ListUseCase',
          fieldName: 'watch${entityName}List',
          presenterMethod:
              '''  Stream<Result<List<$entityName>, AppFailure>> watch${entityName}List() {
    return executeStream(_watch${entityName}List, const NoParams());
  }''',
        );
      default:
        throw ArgumentError('Unknown method: $method');
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
