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
        if (config.idField == 'null' || config.queryField == 'null') {
          baseClass = 'UseCase<$entityName, NoParams>';
          paramsType = 'NoParams';
          executeBody = 'return _repository.get();';
        } else {
          baseClass =
              'UseCase<$entityName, QueryParams<${config.queryFieldType}>>';
          paramsType = 'QueryParams<${config.queryFieldType}>';
          executeBody = 'return _repository.get(params.query);';
        }
        returnType = entityName;
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
        final dataType =
            config.useMorphy ? '${entityName}Patch' : 'Partial<$entityName>';
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
        if (config.idField == 'null' || config.queryField == 'null') {
          baseClass = 'StreamUseCase<$entityName, NoParams>';
          paramsType = 'NoParams';
          executeBody = 'return _repository.watch();';
        } else {
          baseClass =
              'StreamUseCase<$entityName, QueryParams<${config.queryFieldType}>>';
          paramsType = 'QueryParams<${config.queryFieldType}>';
          executeBody = 'return _repository.watch(params.query);';
        }
        returnType = entityName;
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
    // Strip "UseCase" suffix if present for cleaner file names
    final baseName = config.name.endsWith('UseCase') 
        ? config.name.substring(0, config.name.length - 7)
        : config.name;
    final className = '${baseName}UseCase';
    final classSnake = StringUtils.camelToSnake(baseName);
    final fileName = '${classSnake}_usecase.dart';

    final usecasePathParts = <String>[outputDir, 'domain', 'usecases'];
    // Use domain folder for custom UseCases
    if (config.domain != null) {
      usecasePathParts.add(config.domain!);
    } else {
      usecasePathParts.add(classSnake);
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
      final repoPath = '../../repositories/${repoSnake}_repository.dart';

      // Ensure Repository suffix
      final repoClassName =
          repo.endsWith('Repository') ? repo : '${repo}Repository';
      final repoFieldName =
          '_${StringUtils.pascalToCamel(repoSnake)}Repository';

      repoImports.add("import '$repoPath';");
      repoFields.add('  final $repoClassName $repoFieldName;');
      repoParams.add('this.$repoFieldName');
    }

    // Auto-import potential entity types from params and returns
    final entityImports = _getPotentialEntityImports([paramsType, returnsType]);
    for (final entityImport in entityImports) {
      final entitySnake = StringUtils.camelToSnake(entityImport);
      final entityPath = '../../entities/$entitySnake/$entitySnake.dart';
      repoImports.add("import '$entityPath';");
    }

    String executeMethod;
    if (config.useCaseType == 'stream') {
      if (repoFields.isNotEmpty) {
        final methodName = config.getRepoMethodName();
        final repoField = repoFields.first.split(' ').last.replaceAll(';', '');
        executeMethod = '''
  @override
  Stream<$returnsType> execute($paramsType params, CancelToken? cancelToken) {
    return $repoField.$methodName(params);
  }''';
      } else {
        executeMethod = '''
  @override
  Stream<$returnsType> execute($paramsType params, CancelToken? cancelToken) {
    throw UnimplementedError();
  }''';
      }
    } else if (config.useCaseType == 'background') {
      executeMethod = '''
  @override
  BackgroundTask<$paramsType> buildTask() => _process;

  static void _process(BackgroundTaskContext<$paramsType> context) {
    try {
      final params = context.params;
      
      // TODO: Implement your background processing logic here
      final result = processData(params); // Replace with actual implementation
      
      context.sendData(result);
      context.sendDone();
    } catch (e, stackTrace) {
      context.sendError(e, stackTrace);
    }
  }
  
  // TODO: Implement this method with your actual processing logic
  static $returnsType processData($paramsType params) {
    throw UnimplementedError('Implement your background processing logic');
  }''';
    } else {
      final methodName = config.getRepoMethodName();
      final repoField = repoFields.isNotEmpty
          ? repoFields.first.split(' ').last.replaceAll(';', '')
          : '';
      executeMethod = '''
  @override
  Future<$returnsType> execute($paramsType params, CancelToken? cancelToken) async {
    cancelToken?.throwIfCancelled();
    return await $repoField.$methodName(params);
  }''';
    }

    final cliCommand = config.repo != null
        ? '// zfa generate ${config.name} --repo=${config.repo} --domain=${config.effectiveDomain} --params=$paramsType --returns=$returnsType${config.useCaseType != 'usecase' ? ' --type=${config.useCaseType}' : ''}${config.repoMethod != null ? ' --method=${config.repoMethod}' : ''}'
        : '// zfa generate ${config.name} --params=$paramsType --returns=$returnsType --type=${config.useCaseType}';

    final content = '''
// Generated by zfa
$cliCommand

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

  Future<GeneratedFile> generateOrchestrator() async {
    final className = '${config.name}UseCase';
    final classSnake = StringUtils.camelToSnake(config.name);
    final fileName = '${classSnake}_usecase.dart';

    final usecasePathParts = <String>[
      outputDir,
      'domain',
      'usecases',
      config.effectiveDomain
    ];
    final usecaseDirPath = path.joinAll(usecasePathParts);
    final filePath = path.join(usecaseDirPath, fileName);

    final paramsType = config.paramsType!;
    final returnsType = config.returnsType!;

    String baseClass;
    String executeSignature;
    switch (config.useCaseType) {
      case 'stream':
        baseClass = 'StreamUseCase<$returnsType, $paramsType>';
        executeSignature =
            'Stream<$returnsType> execute($paramsType params, CancelToken? cancelToken) async*';
        break;
      case 'completable':
        baseClass = 'CompletableUseCase<$paramsType>';
        executeSignature =
            'Future<void> execute($paramsType params, CancelToken? cancelToken) async';
        break;
      default:
        baseClass = 'UseCase<$returnsType, $paramsType>';
        executeSignature =
            'Future<$returnsType> execute($paramsType params, CancelToken? cancelToken) async';
    }

    // Resolve UseCase imports
    final usecaseImports = <String>[];
    final usecaseFields = <String>[];
    final usecaseParams = <String>[];

    for (final usecaseName in config.usecases) {
      final usecasePath = _resolveUseCasePath(usecaseName);
      final usecaseClassName = usecaseName.endsWith('UseCase')
          ? usecaseName
          : '${usecaseName}UseCase';
      // Remove UseCase suffix for field name
      final baseName = usecaseName.replaceAll('UseCase', '');
      final fieldName = '_${StringUtils.pascalToCamel(baseName)}';

      usecaseImports.add("import '$usecasePath';");
      usecaseFields.add('  final $usecaseClassName $fieldName;');
      usecaseParams.add('this.$fieldName');
    }

    // Add entity imports for params and returns
    final entityImports = _getPotentialEntityImports([paramsType, returnsType]);
    for (final entityImport in entityImports) {
      final entitySnake = StringUtils.camelToSnake(entityImport);
      final entityPath = '../../entities/$entitySnake/$entitySnake.dart';
      usecaseImports.add("import '$entityPath';");
    }

    final content = '''
// Generated by zfa
// zfa generate ${config.name} --usecases=${config.usecases.join(',')} --domain=${config.effectiveDomain} --params=$paramsType --returns=$returnsType

import 'package:zuraffa/zuraffa.dart';
${usecaseImports.join('\n')}

/// Orchestrator UseCase that composes multiple UseCases.
class $className extends $baseClass {
${usecaseFields.join('\n')}

  $className(
    ${usecaseParams.join(',\n    ')},
  );

  @override
  $executeSignature {
    cancelToken?.throwIfCancelled();
    
    // TODO: Orchestrate the UseCases
    // Available UseCases:
${config.usecases.map((u) => '    // - _${StringUtils.pascalToCamel(u.replaceAll('UseCase', ''))}.execute(...)').join('\n')}
    
    throw UnimplementedError('Implement orchestration logic');
  }
}
''';

    return FileUtils.writeFile(
      filePath,
      content,
      'usecase_orchestrator',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<List<GeneratedFile>> generatePolymorphic() async {
    final files = <GeneratedFile>[];
    final baseClassName = '${config.name}UseCase';
    final classSnake = StringUtils.camelToSnake(config.name);

    final usecasePathParts = <String>[
      outputDir,
      'domain',
      'usecases',
      config.effectiveDomain
    ];
    final usecaseDirPath = path.joinAll(usecasePathParts);

    final paramsType = config.paramsType!;
    final returnsType = config.returnsType!;
    final repoName = config.repo != null ? '${config.repo}Repository' : null;

    String baseClass;
    String executeSignature;
    switch (config.useCaseType) {
      case 'stream':
        baseClass = 'StreamUseCase<$returnsType, $paramsType>';
        executeSignature =
            'Stream<$returnsType> execute($paramsType params, CancelToken? cancelToken) async*';
        break;
      case 'background':
        baseClass = 'BackgroundUseCase<$returnsType, $paramsType>';
        executeSignature = 'BackgroundTask<$paramsType> buildTask()';
        break;
      case 'completable':
        baseClass = 'CompletableUseCase<$paramsType>';
        executeSignature =
            'Future<void> execute($paramsType params, CancelToken? cancelToken) async';
        break;
      default:
        baseClass = 'UseCase<$returnsType, $paramsType>';
        executeSignature =
            'Future<$returnsType> execute($paramsType params, CancelToken? cancelToken) async';
    }

    // Generate abstract base
    final abstractFileName = '${classSnake}_usecase.dart';
    final abstractFilePath = path.join(usecaseDirPath, abstractFileName);
    final abstractContent = '''
// Generated by zfa
// zfa generate ${config.name} --type=${config.useCaseType} --variants=${config.variants.join(',')} --domain=${config.effectiveDomain}

import 'package:zuraffa/zuraffa.dart';

/// Abstract base for polymorphic ${config.name} UseCases.
abstract class $baseClassName extends $baseClass {
  // Common logic can go here
}
''';

    files.add(await FileUtils.writeFile(
      abstractFilePath,
      abstractContent,
      'usecase_polymorphic_base',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    ));

    // Generate concrete variants
    for (final variant in config.variants) {
      final variantClassName = '$variant${config.name}UseCase';
      final variantSnake = StringUtils.camelToSnake('$variant${config.name}');
      final variantFileName = '${variantSnake}_usecase.dart';
      final variantFilePath = path.join(usecaseDirPath, variantFileName);

      // Ensure Repository suffix
      final repoClassName = repoName != null && repoName.endsWith('Repository')
          ? repoName
          : repoName != null
              ? '${repoName}Repository'
              : null;
      final repoSnake = config.repo != null
          ? StringUtils.camelToSnake(config.repo!.replaceAll('Repository', ''))
          : '';
      final repoFieldName =
          repoClassName != null ? '_${repoSnake}Repository' : '';

      final repoField =
          repoClassName != null ? '  final $repoClassName $repoFieldName;' : '';
      final repoParam = repoClassName != null
          ? '  $variantClassName(this.$repoFieldName);'
          : '';

      String executeMethod;
      if (config.useCaseType == 'background') {
        executeMethod = '''
  @override
  BackgroundTask<$paramsType> buildTask() => _process;

  static void _process(BackgroundTaskContext<$paramsType> context) {
    try {
      // TODO: Implement $variant-specific background processing
      throw UnimplementedError('Implement $variant processing');
    } catch (e, stackTrace) {
      context.sendError(e, stackTrace);
    }
  }''';
      } else {
        final methodName = config.getRepoMethodName(variant);

        String methodCall;
        if (repoFieldName.isNotEmpty) {
          if (config.useCaseType == 'stream') {
            methodCall = 'return $repoFieldName.$methodName(params);';
          } else {
            methodCall = 'return await $repoFieldName.$methodName(params);';
          }
        } else {
          methodCall =
              'throw UnimplementedError(\'Implement $variant logic\');';
        }

        executeMethod = '''
  @override
  $executeSignature {
    cancelToken?.throwIfCancelled();
    $methodCall
  }''';
      }

      final cliCommand =
          '// zfa generate ${config.name} --type=${config.useCaseType} --variants=${config.variants.join(',')} --domain=${config.effectiveDomain}${config.repo != null ? ' --repo=${config.repo}' : ''}${config.repoMethod != null ? ' --method=${config.repoMethod}' : ''}';

      final variantContent = '''
// Generated by zfa
$cliCommand

import 'package:zuraffa/zuraffa.dart';
import '$abstractFileName';

/// $variant variant of ${config.name}UseCase.
class $variantClassName extends $baseClassName {
$repoField

$repoParam

$executeMethod
}
''';

      files.add(await FileUtils.writeFile(
        variantFilePath,
        variantContent,
        'usecase_polymorphic_variant',
        force: force,
        dryRun: dryRun,
        verbose: verbose,
      ));
    }

    // Generate factory
    final factoryClassName = '${config.name}UseCaseFactory';
    final factoryFileName = '${classSnake}_usecase_factory.dart';
    final factoryFilePath = path.join(usecaseDirPath, factoryFileName);

    final factoryFields = config.variants
        .map((v) =>
            '  final $v${config.name}UseCase _${StringUtils.pascalToCamel(v)};')
        .join('\n');
    final factoryParams = config.variants
        .map((v) => 'this._${StringUtils.pascalToCamel(v)}')
        .join(',\n    ');
    final factoryCases = config.variants
        .map((v) => '      $v$paramsType => _${StringUtils.pascalToCamel(v)},')
        .join('\n');

    final factoryContent = '''
// Generated by zfa
// zfa generate ${config.name} --type=${config.useCaseType} --variants=${config.variants.join(',')} --domain=${config.effectiveDomain}

import '$abstractFileName';
${config.variants.map((v) => "import '${StringUtils.camelToSnake('$v${config.name}')}_usecase.dart';").join('\n')}

/// Factory for creating appropriate ${config.name}UseCase variant.
class $factoryClassName {
$factoryFields

  $factoryClassName(
    $factoryParams,
  );

  $baseClassName forParams($paramsType params) {
    return switch (params.runtimeType) {
$factoryCases
      _ => throw UnimplementedError('Unknown params type: \${params.runtimeType}'),
    };
  }
}
''';

    files.add(await FileUtils.writeFile(
      factoryFilePath,
      factoryContent,
      'usecase_polymorphic_factory',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    ));

    return files;
  }

  String _resolveUseCasePath(String usecaseName) {
    // Remove "UseCase" suffix if present
    final name = usecaseName.endsWith('UseCase')
        ? usecaseName.substring(0, usecaseName.length - 7)
        : usecaseName;

    final snakeName = StringUtils.camelToSnake(name);

    // Try convention first
    final conventionPath = '../$snakeName/${snakeName}_usecase.dart';
    final fullPath = path.join(outputDir, 'domain', 'usecases', snakeName,
        '${snakeName}_usecase.dart');

    if (File(fullPath).existsSync()) {
      return conventionPath;
    }

    // Fallback: Search in usecases folder
    final usecasesDir = Directory(path.join(outputDir, 'domain', 'usecases'));
    if (usecasesDir.existsSync()) {
      final files = usecasesDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('_usecase.dart'));

      for (final file in files) {
        final content = file.readAsStringSync();
        final className = usecaseName.endsWith('UseCase')
            ? usecaseName
            : '${usecaseName}UseCase';
        if (content.contains('class $className')) {
          // Calculate relative path
          final relativePath = path.relative(file.path,
              from: path.join(
                  outputDir, 'domain', 'usecases', config.effectiveDomain));
          return relativePath;
        }
      }
    }

    throw Exception('UseCase not found: $usecaseName\n'
        'Expected at: $fullPath\n'
        'Generate it first with: zfa generate $name --domain=<domain> --repo=<Repository> --params=<Type> --returns=<Type>');
  }

  UseCaseInfo getUseCaseInfo(
      String method, String entityName, String entityCamel) {
    switch (method) {
      case 'get':
        return UseCaseInfo(
          className: 'Get${entityName}UseCase',
          fieldName: 'get$entityName',
          presenterMethod: config.idField == 'null' ||
                  config.queryField == 'null'
              ? '''  Future<Result<$entityName, AppFailure>> get$entityName() {
    return _get$entityName.call(const NoParams());
  }'''
              : '''  Future<Result<$entityName, AppFailure>> get$entityName(${config.queryFieldType} ${config.queryField}) {
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
        final updateDataType =
            config.useMorphy ? '${entityName}Patch' : 'Partial<$entityName>';
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
          presenterMethod: config.idField == 'null' ||
                  config.queryField == 'null'
              ? '''  Stream<Result<$entityName, AppFailure>> watch$entityName() {
    return _watch$entityName.call(const NoParams());
  }'''
              : '''  Stream<Result<$entityName, AppFailure>> watch$entityName(${config.queryFieldType} ${config.queryField}) {
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
        path.join(
            outputDir, 'domain', 'entities', entitySnake, '$entitySnake.dart'),
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
          print(
              '  ℹ Entity file for $entitySnake not found, skipping auto-validation');
        }
        return [];
      }

      final content = file.readAsStringSync();
      // Regex to find fields (usually final or non-static members)
      // Matches both 'final int id;' and 'String? name;'
      // but avoids methods and static members.
      final regex = RegExp(r'^\s+(?:final\s+)?(?:[\w<>,?!\s]+)\s+(\w+)\s*;',
          multiLine: true);
      final matches = regex.allMatches(content);

      final fields = matches
          .map((m) => m.group(1)!)
          .where((f) => f != 'hashCode')
          .toList();

      if (verbose && fields.isNotEmpty) {
        print(
            '  ✓ Automatically extracted fields for validation: ${fields.join(', ')}');
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
