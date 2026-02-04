import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/generator_config.dart';
import '../models/generated_file.dart';
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

    // Generate mock datasource DI file
    if (config.generateMock && !config.generateMockDataOnly) {
      files.add(await _generateMockDataSourceDI());
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

    final content =
        '''
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
  getIt.registerLazySingleton<$dataSourceName>(
    () => $dataSourceName(Hive.box<$entityName>('${entitySnake}s')),
  );'''
        : '''
  getIt.registerLazySingleton<$dataSourceName>(
    () => $dataSourceName(),
  );''';

    final content =
        '''
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

    final content =
        '''
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
      final remoteDataSourceName = config.useMockInDi
          ? '${entityName}MockDataSource'
          : '${entityName}RemoteDataSource';
      final localDataSourceName = '${entityName}LocalDataSource';

      final policyType = config.cachePolicy;
      final ttlMinutes = config.ttlMinutes ?? 1440;
      final policyFunctionName = policyType == 'daily'
          ? 'createDailyCachePolicy'
          : policyType == 'restart'
          ? 'createAppRestartCachePolicy'
          : 'createTtl${ttlMinutes}MinutesCachePolicy';

      final remoteDataSourceImport = config.useMockInDi
          ? "import '../../data/data_sources/$entitySnake/${entitySnake}_mock_data_source.dart';"
          : "import '../../data/data_sources/$entitySnake/${entitySnake}_remote_data_source.dart';";

      cacheImports =
          '''
$remoteDataSourceImport
import '../../data/data_sources/$entitySnake/${entitySnake}_local_data_source.dart';
import '../../cache/${policyType == 'ttl'
              ? 'ttl_${ttlMinutes}_minutes_cache_policy.dart'
              : policyType == 'daily'
              ? 'daily_cache_policy.dart'
              : 'app_restart_cache_policy.dart'}';''';
      registration =
          '''
  getIt.registerLazySingleton<$repoName>(
    () => $dataRepoName(
      getIt<$remoteDataSourceName>(),
      getIt<$localDataSourceName>(),
      $policyFunctionName(),
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
      registration =
          '''
  getIt.registerLazySingleton<$repoName>(
    () => $dataRepoName(getIt<$dataSourceName>()),
  );''';
    }

    final content =
        '''
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

  Future<void> _regenerateIndexFiles() async {
    await _regenerateIndexFile('datasources', 'DataSources');
    await _regenerateIndexFile('repositories', 'Repositories');
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
        .where(
          (f) => f.path.endsWith('_di.dart') && !f.path.endsWith('index.dart'),
        )
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
      final match = RegExp(
        r'void (register\w+)\(GetIt getIt\)',
      ).firstMatch(content);
      if (match != null) {
        registrations.add('  ${match.group(1)}(getIt);');
      }
    }

    final content =
        '''
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

import 'package:get_it/get_it.dart';
import 'datasources/index.dart';
import 'repositories/index.dart';

void setupDependencies(GetIt getIt) {
  registerAllDataSources(getIt);
  registerAllRepositories(getIt);
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
}

class UseCaseInfo {
  final String className;
  final String fieldName;

  UseCaseInfo({required this.className, required this.fieldName});
}
