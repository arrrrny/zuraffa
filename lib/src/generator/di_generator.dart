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

    // Generate service DI file (only if not already registered)
    if (config.hasService) {
      final serviceFile = await _generateServiceDI();
      if (serviceFile != null) {
        files.add(serviceFile);
      }
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

  /// Generate service DI registration file.
  /// Returns null if the service is already registered.
  Future<GeneratedFile?> _generateServiceDI() async {
    final serviceName = config.effectiveService!;
    final serviceSnake = config.serviceSnake!;
    final fileName = '${serviceSnake}_service_di.dart';

    final diPath = path.join(outputDir, 'di', 'services', fileName);

    // Check if already registered
    if (File(diPath).existsSync() && !force) {
      if (verbose) {
        print('⏭️  Service DI already exists: $fileName (skipped)');
      }
      return null;
    }

    final content = '''
// Auto-generated DI registration for $serviceName
// TODO: Replace with your actual service implementation
import 'package:get_it/get_it.dart';
import '../../domain/services/${serviceSnake}_service.dart';

/// Register $serviceName with dependency injection.
///
/// You need to create a concrete implementation of $serviceName
/// and register it here. Example:
///
/// ```dart
/// import '../../data/services/${serviceSnake}_service_impl.dart';
///
/// void register$serviceName(GetIt getIt) {
///   getIt.registerLazySingleton<$serviceName>(
///     () => ${serviceName}Impl(),
///   );
/// }
/// ```
void register$serviceName(GetIt getIt) {
  // TODO: Replace with your service implementation
  // getIt.registerLazySingleton<$serviceName>(
  //   () => ${serviceName}Impl(),
  // );
  throw UnimplementedError(
    'Register your $serviceName implementation in $fileName',
  );
}
''';

    return FileUtils.writeFile(
      diPath,
      content,
      'di_service',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<void> _regenerateIndexFiles() async {
    await _regenerateIndexFile('datasources', 'DataSources');
    await _regenerateIndexFile('repositories', 'Repositories');
    await _regenerateIndexFile('services', 'Services');
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

    // Check which folders exist
    final datasourcesDir = Directory(path.join(outputDir, 'di', 'datasources'));
    final repositoriesDir = Directory(path.join(outputDir, 'di', 'repositories'));
    final servicesDir = Directory(path.join(outputDir, 'di', 'services'));

    final exports = <String>[];
    final imports = <String>[];
    final registrations = <String>[];

    if (datasourcesDir.existsSync() && _hasIndexFile(datasourcesDir)) {
      exports.add("export 'datasources/index.dart';");
      imports.add("import 'datasources/index.dart';");
      registrations.add('  registerAllDataSources(getIt);');
    }

    if (repositoriesDir.existsSync() && _hasIndexFile(repositoriesDir)) {
      exports.add("export 'repositories/index.dart';");
      imports.add("import 'repositories/index.dart';");
      registrations.add('  registerAllRepositories(getIt);');
    }

    if (servicesDir.existsSync() && _hasIndexFile(servicesDir)) {
      exports.add("export 'services/index.dart';");
      imports.add("import 'services/index.dart';");
      registrations.add('  registerAllServices(getIt);');
    }

    final content = '''
// Auto-generated - DO NOT EDIT
${exports.join('\n')}

import 'package:get_it/get_it.dart';
${imports.join('\n')}

void setupDependencies(GetIt getIt) {
${registrations.join('\n')}
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

  bool _hasIndexFile(Directory dir) {
    final indexFile = File(path.join(dir.path, 'index.dart'));
    return indexFile.existsSync() || !dryRun;
  }
}

class UseCaseInfo {
  final String className;
  final String fieldName;

  UseCaseInfo({required this.className, required this.fieldName});
}
