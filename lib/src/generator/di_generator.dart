import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/generator_config.dart';
import '../models/generated_file.dart';
import '../utils/string_utils.dart';
import '../utils/file_utils.dart';

class DiGenerator {
  final GeneratorConfig config;
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  DiGenerator({
    required this.config,
    required this.outputDir,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
  });

  Future<List<GeneratedFile>> generate() async {
    final files = <GeneratedFile>[];

    // Generate datasource DI files
    if (config.generateData) {
      if (config.enableCache) {
        // Generate remote and local datasource DI files
        files.add(await _generateRemoteDataSourceDI());
        files.add(await _generateLocalDataSourceDI());
      } else if (config.useMockInDi) {
        // Generate mock datasource DI file
        files.add(await _generateMockDataSourceDI());
      } else {
        // Generate remote datasource DI file
        files.add(await _generateRemoteDataSourceDI());
      }
    }

    // Generate repository DI file
    if (config.generateData || config.generateRepository) {
      files.add(await _generateRepositoryDI());
    }

    // Generate usecase DI files
    for (final method in config.methods) {
      files.add(await _generateUseCaseDI(method));
    }

    // Generate mock datasource DI file
    if (config.generateMock && !config.generateMockDataOnly) {
      files.add(await _generateMockDataSourceDI());
    }

    // Generate presenter and controller DI files
    if (config.generateVpc) {
      files.add(await _generatePresenterDI());
      files.add(await _generateControllerDI());
    }

    // Regenerate all index files
    await _regenerateIndexFiles();

    return files;
  }

  Future<GeneratedFile> _generateRemoteDataSourceDI() async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final dataSourceName = '${entityName}RemoteDataSource';
    final fileName = '${entitySnake}_remote_data_source_di.dart';

    final diPath = path.join(outputDir, 'di', 'datasources', fileName);

    final content = '''
// Auto-generated DI registration for $dataSourceName
import 'package:get_it/get_it.dart';
import '../../data/data_sources/$entitySnake/${entitySnake}_remote_data_source.dart';

void register$dataSourceName(GetIt getIt) {
  getIt.registerLazySingleton<$dataSourceName>(
    () => $dataSourceName(),
  );
}
''';

    return FileUtils.writeFile(
      diPath,
      content,
      'di_datasource',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> _generateLocalDataSourceDI() async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final dataSourceName = '${entityName}LocalDataSource';
    final fileName = '${entitySnake}_local_data_source_di.dart';

    final diPath = path.join(outputDir, 'di', 'datasources', fileName);

    final hiveBoxSetup = config.cacheStorage == 'hive'
        ? '''
  // TODO: Open Hive box before calling this
  // final ${entitySnake}Box = await Hive.openBox<$entityName>('${entitySnake}s');
  // Then pass it to the constructor
  getIt.registerLazySingleton<$dataSourceName>(
    () => $dataSourceName(getIt<Box<$entityName>>()),
  );'''
        : '''
  getIt.registerLazySingleton<$dataSourceName>(
    () => $dataSourceName(),
  );''';

    final content = '''
// Auto-generated DI registration for $dataSourceName
import 'package:get_it/get_it.dart';
import '../../data/data_sources/$entitySnake/${entitySnake}_local_data_source.dart';
${config.cacheStorage == 'hive' ? "import 'package:hive_ce_flutter/hive_ce_flutter.dart';\nimport '../../domain/entities/$entitySnake/$entitySnake.dart';" : ''}

void register$dataSourceName(GetIt getIt) {
$hiveBoxSetup
}
''';

    return FileUtils.writeFile(
      diPath,
      content,
      'di_datasource',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> _generateMockDataSourceDI() async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final dataSourceName = '${entityName}MockDataSource';
    final fileName = '${entitySnake}_mock_data_source_di.dart';

    final diPath = path.join(outputDir, 'di', 'datasources', fileName);

    final content = '''
// Auto-generated DI registration for $dataSourceName
import 'package:get_it/get_it.dart';
import '../../data/data_sources/$entitySnake/${entitySnake}_mock_data_source.dart';

void register$dataSourceName(GetIt getIt) {
  getIt.registerLazySingleton<$dataSourceName>(
    () => $dataSourceName(),
  );
}
''';

    return FileUtils.writeFile(
      diPath,
      content,
      'di_datasource',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> _generateRepositoryDI() async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final repoName = '${entityName}Repository';
    final dataRepoName = 'Data${entityName}Repository';
    final fileName = '${entitySnake}_repository_di.dart';

    final diPath = path.join(outputDir, 'di', 'repositories', fileName);

    final String registration;
    final String cacheImports;
    if (config.enableCache) {
      final remoteDataSourceName = '${entityName}RemoteDataSource';
      final localDataSourceName = '${entityName}LocalDataSource';
      cacheImports = '''
import '../../data/data_sources/$entitySnake/${entitySnake}_remote_data_source.dart';
import '../../data/data_sources/$entitySnake/${entitySnake}_local_data_source.dart';
import 'package:zuraffa/zuraffa.dart';''';
      registration = '''
  getIt.registerLazySingleton<$repoName>(
    () => $dataRepoName(
      getIt<$remoteDataSourceName>(),
      getIt<$localDataSourceName>(),
      getIt<CachePolicy>(),
    ),
  );''';
    } else {
      // Use mock or remote datasource based on flag
      final dataSourceName = config.useMockInDi
          ? '${entityName}MockDataSource'
          : '${entityName}RemoteDataSource';
      final dataSourceImport = config.useMockInDi
          ? "import '../../data/data_sources/$entitySnake/${entitySnake}_mock_data_source.dart';"
          : "import '../../data/data_sources/$entitySnake/${entitySnake}_remote_data_source.dart';";
      cacheImports = dataSourceImport;
      registration = '''
  getIt.registerLazySingleton<$repoName>(
    () => $dataRepoName(getIt<$dataSourceName>()),
  );''';
    }

    final content = '''
// Auto-generated DI registration for $repoName
import 'package:get_it/get_it.dart';
import '../../domain/repositories/${entitySnake}_repository.dart';
import '../../data/repositories/data_${entitySnake}_repository.dart';
$cacheImports

void register$repoName(GetIt getIt) {
$registration
}
''';

    return FileUtils.writeFile(
      diPath,
      content,
      'di_repository',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> _generateUseCaseDI(String method) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final useCaseInfo = _getUseCaseInfo(method);
    final useCaseSnake = StringUtils.camelToSnake(
        useCaseInfo.className.replaceAll('UseCase', ''));
    final fileName = '${useCaseSnake}_usecase_di.dart';

    final diPath = path.join(outputDir, 'di', 'usecases', fileName);

    final subdirectoryPart =
        config.subdirectory != null && config.subdirectory!.isNotEmpty
            ? '/${config.subdirectory!}'
            : '';

    final content = '''
// Auto-generated DI registration for ${useCaseInfo.className}
import 'package:get_it/get_it.dart';
import '../../domain/usecases$subdirectoryPart/$entitySnake/${useCaseSnake}_usecase.dart';
import '../../domain/repositories/${entitySnake}_repository.dart';

void register${useCaseInfo.className}(GetIt getIt) {
  getIt.registerFactory<${useCaseInfo.className}>(
    () => ${useCaseInfo.className}(getIt<${entityName}Repository>()),
  );
}
''';

    return FileUtils.writeFile(
      diPath,
      content,
      'di_usecase',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> _generatePresenterDI() async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final presenterName = '${entityName}Presenter';
    final repoName = '${entityName}Repository';
    final fileName = '${entitySnake}_presenter_di.dart';

    final diPath = path.join(outputDir, 'di', 'presenters', fileName);

    final content = '''
// Auto-generated DI registration for $presenterName
import 'package:get_it/get_it.dart';
import '../../presentation/pages/$entitySnake/${entitySnake}_presenter.dart';
import '../../domain/repositories/${entitySnake}_repository.dart';

void register$presenterName(GetIt getIt) {
  getIt.registerFactory(
    () => $presenterName(
      ${StringUtils.pascalToCamel(entityName)}Repository: getIt<$repoName>(),
    ),
  );
}
''';

    return FileUtils.writeFile(
      diPath,
      content,
      'di_presenter',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> _generateControllerDI() async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final controllerName = '${entityName}Controller';
    final presenterName = '${entityName}Presenter';
    final fileName = '${entitySnake}_controller_di.dart';

    final diPath = path.join(outputDir, 'di', 'controllers', fileName);

    final content = '''
// Auto-generated DI registration for $controllerName
import 'package:get_it/get_it.dart';
import '../../presentation/pages/$entitySnake/${entitySnake}_controller.dart';
import '../../presentation/pages/$entitySnake/${entitySnake}_presenter.dart';

void register$controllerName(GetIt getIt) {
  getIt.registerFactory(
    () => $controllerName(getIt<$presenterName>()),
  );
}
''';

    return FileUtils.writeFile(
      diPath,
      content,
      'di_controller',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<void> _regenerateIndexFiles() async {
    await _regenerateIndexFile('datasources', 'DataSources');
    await _regenerateIndexFile('repositories', 'Repositories');
    await _regenerateIndexFile('usecases', 'UseCases');
    await _regenerateIndexFile('presenters', 'Presenters');
    await _regenerateIndexFile('controllers', 'Controllers');
    await _regenerateMainIndex();
  }

  Future<void> _regenerateIndexFile(String folder, String label) async {
    final dirPath = path.join(outputDir, 'di', folder);
    final indexPath = path.join(dirPath, 'index.dart');

    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      return;
    }

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('_di.dart') && !f.path.endsWith('index.dart'))
        .toList();

    if (files.isEmpty) {
      return;
    }

    final imports = <String>[];
    final registrations = <String>[];

    for (final file in files) {
      final fileName = path.basename(file.path);
      imports.add("import '$fileName';");

      // Extract registration function name from file
      final content = file.readAsStringSync();
      final match =
          RegExp(r'void (register\w+)\(GetIt getIt\)').firstMatch(content);
      if (match != null) {
        registrations.add('  ${match.group(1)}(getIt);');
      }
    }

    final content = '''
// Auto-generated - DO NOT EDIT
${imports.join('\n')}

import 'package:get_it/get_it.dart';

void registerAll$label(GetIt getIt) {
${registrations.join('\n')}
}
''';

    await FileUtils.writeFile(
      indexPath,
      content,
      'di_index',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<void> _regenerateMainIndex() async {
    final mainIndexPath = path.join(outputDir, 'di', 'index.dart');

    final content = '''
// Auto-generated - DO NOT EDIT
export 'datasources/index.dart';
export 'repositories/index.dart';
export 'usecases/index.dart';
export 'presenters/index.dart';
export 'controllers/index.dart';

import 'package:get_it/get_it.dart';
import 'datasources/index.dart';
import 'repositories/index.dart';
import 'usecases/index.dart';
import 'presenters/index.dart';
import 'controllers/index.dart';

void setupDependencies(GetIt getIt) {
  registerAllDataSources(getIt);
  registerAllRepositories(getIt);
  registerAllUseCases(getIt);
  registerAllPresenters(getIt);
  registerAllControllers(getIt);
}
''';

    await FileUtils.writeFile(
      mainIndexPath,
      content,
      'di_main_index',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  UseCaseInfo _getUseCaseInfo(String method) {
    final entityName = config.name;
    final entityCamel = config.nameCamel;

    switch (method) {
      case 'get':
        return UseCaseInfo(
          className: 'Get${entityName}UseCase',
          fieldName: 'get${entityName}UseCase',
        );
      case 'getList':
        return UseCaseInfo(
          className: 'Get${entityName}ListUseCase',
          fieldName: 'get${entityName}ListUseCase',
        );
      case 'create':
        return UseCaseInfo(
          className: 'Create${entityName}UseCase',
          fieldName: 'create${entityName}UseCase',
        );
      case 'update':
        return UseCaseInfo(
          className: 'Update${entityName}UseCase',
          fieldName: 'update${entityName}UseCase',
        );
      case 'delete':
        return UseCaseInfo(
          className: 'Delete${entityName}UseCase',
          fieldName: 'delete${entityName}UseCase',
        );
      case 'watch':
        return UseCaseInfo(
          className: 'Watch${entityName}UseCase',
          fieldName: 'watch${entityName}UseCase',
        );
      case 'watchList':
        return UseCaseInfo(
          className: 'Watch${entityName}ListUseCase',
          fieldName: 'watch${entityName}ListUseCase',
        );
      default:
        return UseCaseInfo(
          className: '${entityName}UseCase',
          fieldName: '${entityCamel}UseCase',
        );
    }
  }
}

class UseCaseInfo {
  final String className;
  final String fieldName;

  UseCaseInfo({
    required this.className,
    required this.fieldName,
  });
}
