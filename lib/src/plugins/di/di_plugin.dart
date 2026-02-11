import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../core/ast/append_executor.dart';
import '../../core/ast/strategies/append_strategy.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import 'builders/registration_builder.dart';
import 'detectors/registration_detector.dart';

class DiPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final RegistrationBuilder registrationBuilder;
  final RegistrationDetector registrationDetector;
  final AppendExecutor appendExecutor;

  DiPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    RegistrationBuilder? registrationBuilder,
    RegistrationDetector? registrationDetector,
    AppendExecutor? appendExecutor,
  }) : registrationBuilder = registrationBuilder ?? const RegistrationBuilder(),
       registrationDetector =
           registrationDetector ?? const RegistrationDetector(),
       appendExecutor = appendExecutor ?? AppendExecutor();

  @override
  String get id => 'di';

  @override
  String get name => 'DI Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.generateDi) {
      return [];
    }
    final files = <GeneratedFile>[];

    if (config.generateData && !config.hasService) {
      if (config.enableCache) {
        files.add(await _generateRemoteDataSourceDI(config));
        files.add(await _generateLocalDataSourceDI(config));
      } else if (config.useMockInDi) {
        files.add(await _generateMockDataSourceDI(config));
      } else {
        files.add(await _generateRemoteDataSourceDI(config));
      }
    }

    if ((config.generateData || config.generateRepository) &&
        !config.hasService) {
      files.add(await _generateRepositoryDI(config));
    }

    if (config.generateMock &&
        !config.generateMockDataOnly &&
        !config.hasService) {
      files.add(await _generateMockDataSourceDI(config));
    }

    if (config.hasService) {
      if (config.generateData) {
        final serviceFile = await _generateServiceDI(config);
        if (serviceFile != null) {
          files.add(serviceFile);
        }
        final providerFile = await _generateProviderDI(config);
        if (providerFile != null) {
          files.add(providerFile);
        }
      } else {
        final serviceFile = await _generateServiceDI(config);
        if (serviceFile != null) {
          files.add(serviceFile);
        }
      }
    }

    await _regenerateIndexFiles();

    return files;
  }

  Future<GeneratedFile> _generateRemoteDataSourceDI(
    GeneratorConfig config,
  ) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final dataSourceName = '${entityName}RemoteDataSource';
    final fileName = '${entitySnake}_remote_data_source_di.dart';
    final diPath = path.join(outputDir, 'di', 'datasources', fileName);
    final registrationCall = refer('getIt')
        .property('registerLazySingleton')
        .call(
          [
            Method(
              (m) => m
                ..lambda = true
                ..body = refer(dataSourceName).call([]).code,
            ).closure,
          ],
          {},
          [refer(dataSourceName)],
        );

    final content = registrationBuilder.buildRegistrationFile(
      functionName: 'register$dataSourceName',
      imports: [
        'package:get_it/get_it.dart',
        '../../data/data_sources/$entitySnake/${entitySnake}_remote_data_source.dart',
      ],
      body: Block(
        (b) => b..statements.add(registrationCall.statement),
      ),
    );

    return FileUtils.writeFile(
      diPath,
      content,
      'di_datasource',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> _generateLocalDataSourceDI(
    GeneratorConfig config,
  ) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final dataSourceName = '${entityName}LocalDataSource';
    final fileName = '${entitySnake}_local_data_source_di.dart';
    final diPath = path.join(outputDir, 'di', 'datasources', fileName);

    final imports = <String>[
      'package:get_it/get_it.dart',
      '../../data/data_sources/$entitySnake/${entitySnake}_local_data_source.dart',
    ];

    Expression constructorCall;
    if (config.cacheStorage == 'hive') {
      imports.add('package:hive_ce_flutter/hive_ce_flutter.dart');
      imports.add('../../domain/entities/$entitySnake/$entitySnake.dart');
      final boxCall = refer('Hive').property('box').call(
        [literalString('${entitySnake}s')],
        {},
        [refer(entityName)],
      );
      constructorCall = refer(dataSourceName).call([boxCall]);
    } else {
      constructorCall = refer(dataSourceName).call([]);
    }
    final registrationCall = refer('getIt')
        .property('registerLazySingleton')
        .call(
          [
            Method(
              (m) => m
                ..lambda = true
                ..body = constructorCall.code,
            ).closure,
          ],
          {},
          [refer(dataSourceName)],
        );

    final content = registrationBuilder.buildRegistrationFile(
      functionName: 'register$dataSourceName',
      imports: imports,
      body: Block(
        (b) => b..statements.add(registrationCall.statement),
      ),
    );

    return FileUtils.writeFile(
      diPath,
      content,
      'di_datasource',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> _generateMockDataSourceDI(
    GeneratorConfig config,
  ) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final dataSourceName = '${entityName}MockDataSource';
    final fileName = '${entitySnake}_mock_data_source_di.dart';
    final diPath = path.join(outputDir, 'di', 'datasources', fileName);
    final registrationCall = refer('getIt')
        .property('registerLazySingleton')
        .call(
          [
            Method(
              (m) => m
                ..lambda = true
                ..body = refer(dataSourceName).call([]).code,
            ).closure,
          ],
          {},
          [refer(dataSourceName)],
        );

    final content = registrationBuilder.buildRegistrationFile(
      functionName: 'register$dataSourceName',
      imports: [
        'package:get_it/get_it.dart',
        '../../data/data_sources/$entitySnake/${entitySnake}_mock_data_source.dart',
      ],
      body: Block(
        (b) => b..statements.add(registrationCall.statement),
      ),
    );

    return FileUtils.writeFile(
      diPath,
      content,
      'di_datasource',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> _generateRepositoryDI(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final repoName = '${entityName}Repository';
    final dataRepoName = 'Data${entityName}Repository';
    final fileName = '${entitySnake}_repository_di.dart';
    final diPath = path.join(outputDir, 'di', 'repositories', fileName);

    final imports = <String>[
      'package:get_it/get_it.dart',
      '../../domain/repositories/${entitySnake}_repository.dart',
      '../../data/repositories/data_${entitySnake}_repository.dart',
    ];

    Expression constructorCall;
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

      final remoteImport = config.useMockInDi
          ? '../../data/data_sources/$entitySnake/${entitySnake}_mock_data_source.dart'
          : '../../data/data_sources/$entitySnake/${entitySnake}_remote_data_source.dart';
      imports.add(remoteImport);
      imports.add(
        '../../data/data_sources/$entitySnake/${entitySnake}_local_data_source.dart',
      );
      imports.add(
        '../../cache/${policyType == 'ttl'
            ? 'ttl_${ttlMinutes}_minutes_cache_policy.dart'
            : policyType == 'daily'
            ? 'daily_cache_policy.dart'
            : 'app_restart_cache_policy.dart'}',
      );
      constructorCall = refer(dataRepoName).call([
        refer('getIt').call([], {}, [refer(remoteDataSourceName)]),
        refer('getIt').call([], {}, [refer(localDataSourceName)]),
        refer(policyFunctionName).call([]),
      ]);
    } else {
      final dataSourceName = config.useMockInDi
          ? '${entityName}MockDataSource'
          : '${entityName}RemoteDataSource';
      final dataSourceImport = config.useMockInDi
          ? '../../data/data_sources/$entitySnake/${entitySnake}_mock_data_source.dart'
          : '../../data/data_sources/$entitySnake/${entitySnake}_remote_data_source.dart';
      imports.add(dataSourceImport);
      constructorCall = refer(dataRepoName).call([
        refer('getIt').call([], {}, [refer(dataSourceName)]),
      ]);
    }
    final registrationCall = refer('getIt')
        .property('registerLazySingleton')
        .call(
          [
            Method(
              (m) => m
                ..lambda = true
                ..body = constructorCall.code,
            ).closure,
          ],
          {},
          [refer(repoName)],
        );

    final content = registrationBuilder.buildRegistrationFile(
      functionName: 'register$repoName',
      imports: imports,
      body: Block(
        (b) => b..statements.add(registrationCall.statement),
      ),
    );

    return FileUtils.writeFile(
      diPath,
      content,
      'di_repository',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile?> _generateServiceDI(GeneratorConfig config) async {
    final serviceName = config.effectiveService!;
    final serviceSnake = config.serviceSnake!;
    final fileName = '${serviceSnake}_service_di.dart';
    final diPath = path.join(outputDir, 'di', 'services', fileName);

    if (File(diPath).existsSync() && !force) {
      return null;
    }

    final content = registrationBuilder.buildRegistrationFile(
      functionName: 'register$serviceName',
      imports: [
        'package:get_it/get_it.dart',
        '../../domain/services/${serviceSnake}_service.dart',
      ],
      body: Block(
        (b) => b
          ..statements.add(
            refer('UnimplementedError')
                .call([
                  literalString(
                    'Register your $serviceName implementation in $fileName',
                  ),
                ])
                .thrown
                .statement,
          ),
      ),
    );

    return FileUtils.writeFile(
      diPath,
      content,
      'di_service',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile?> _generateProviderDI(GeneratorConfig config) async {
    final serviceName = config.effectiveService!;
    final providerName = config.effectiveProvider!;
    final providerSnake = config.providerSnake!;
    final serviceSnake = config.serviceSnake!;
    final fileName = '${providerSnake}_provider_di.dart';
    final diPath = path.join(outputDir, 'di', 'providers', fileName);

    if (File(diPath).existsSync() && !force) {
      return null;
    }

    final content = registrationBuilder.buildRegistrationFile(
      functionName: 'register$providerName',
      imports: [
        'package:get_it/get_it.dart',
        '../../domain/services/${serviceSnake}_service.dart',
        '../../data/providers/${config.effectiveDomain}/${providerSnake}_provider.dart',
      ],
      body: Block(
        (b) => b
          ..statements.add(
            refer('getIt')
                .property('registerLazySingleton')
                .call(
                  [
                    Method(
                      (m) => m
                        ..lambda = true
                        ..body = refer(providerName).call([]).code,
                    ).closure,
                  ],
                  {},
                  [refer(serviceName)],
                )
                .statement,
          ),
      ),
    );

    return FileUtils.writeFile(
      diPath,
      content,
      'di_provider',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<void> _regenerateIndexFiles() async {
    await _regenerateIndexFile('datasources', 'DataSources');
    await _regenerateIndexFile('repositories', 'Repositories');
    await _regenerateIndexFile('services', 'Services');
    await _regenerateIndexFile('providers', 'Providers');
    await _regenerateMainIndex();
  }

  Future<void> _regenerateIndexFile(String folder, String label) async {
    final dirPath = path.join(outputDir, 'di', folder);
    final indexPath = path.join(dirPath, 'index.dart');

    final registrations = registrationDetector.detectRegistrations(dirPath);
    if (registrations.isEmpty) {
      return;
    }

    final importPaths = [
      'package:get_it/get_it.dart',
      ...registrations.map((r) => r.fileName),
    ];
    final registrationCalls = registrations
        .map((r) => '${r.functionName}(getIt);')
        .toList();
    final functionName = 'registerAll$label';

    String content;
    if (File(indexPath).existsSync() && !force) {
      content = _updateIndexFile(
        existingContent: File(indexPath).readAsStringSync(),
        importPaths: importPaths,
        exportPaths: const [],
        functionName: functionName,
        registrationCalls: registrationCalls,
      );
    } else {
      final directives = importPaths.map(Directive.import).toList();
      final registrationStatements = registrations
          .map(
            (r) => refer(r.functionName).call([refer('getIt')]).statement,
          )
          .toList();
      content = registrationBuilder.buildIndexFile(
        functionName: functionName,
        registrations: registrationStatements,
        directives: directives,
      );
    }

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

    final datasourcesDir = Directory(path.join(outputDir, 'di', 'datasources'));
    final repositoriesDir = Directory(
      path.join(outputDir, 'di', 'repositories'),
    );
    final servicesDir = Directory(path.join(outputDir, 'di', 'services'));
    final providersDir = Directory(path.join(outputDir, 'di', 'providers'));

    final exportPaths = <String>[];
    final importPaths = <String>['package:get_it/get_it.dart'];
    final registrationCalls = <String>[];

    if (datasourcesDir.existsSync() && _hasIndexFile(datasourcesDir)) {
      exportPaths.add('datasources/index.dart');
      importPaths.add('datasources/index.dart');
      registrationCalls.add('registerAllDataSources(getIt);');
    }

    if (repositoriesDir.existsSync() && _hasIndexFile(repositoriesDir)) {
      exportPaths.add('repositories/index.dart');
      importPaths.add('repositories/index.dart');
      registrationCalls.add('registerAllRepositories(getIt);');
    }

    if (servicesDir.existsSync() && _hasIndexFile(servicesDir)) {
      exportPaths.add('services/index.dart');
      importPaths.add('services/index.dart');
      registrationCalls.add('registerAllServices(getIt);');
    }

    if (providersDir.existsSync() && _hasIndexFile(providersDir)) {
      exportPaths.add('providers/index.dart');
      importPaths.add('providers/index.dart');
      registrationCalls.add('registerAllProviders(getIt);');
    }

    if (registrationCalls.isEmpty) {
      return;
    }

    String content;
    if (File(mainIndexPath).existsSync() && !force) {
      content = _updateIndexFile(
        existingContent: File(mainIndexPath).readAsStringSync(),
        importPaths: importPaths,
        exportPaths: exportPaths,
        functionName: 'setupDependencies',
        registrationCalls: registrationCalls,
      );
    } else {
      final directives = [
        ...exportPaths.map(Directive.export),
        ...importPaths.map(Directive.import),
      ];
      final registrationStatements = registrationCalls
          .map(
            (call) => refer(call.split('(').first)
                .call([refer('getIt')]).statement,
          )
          .toList();
      content = registrationBuilder.buildIndexFile(
        functionName: 'setupDependencies',
        registrations: registrationStatements,
        directives: directives,
      );
    }

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

  String _updateIndexFile({
    required String existingContent,
    required List<String> importPaths,
    required List<String> exportPaths,
    required String functionName,
    required List<String> registrationCalls,
  }) {
    var content = existingContent;

    for (final exportPath in exportPaths) {
      final result = appendExecutor.execute(
        AppendRequest.export(source: content, exportPath: exportPath),
      );
      content = result.source;
    }

    for (final importPath in importPaths) {
      final result = appendExecutor.execute(
        AppendRequest.import(source: content, importPath: importPath),
      );
      content = result.source;
    }

    for (final registration in registrationCalls) {
      final result = appendExecutor.execute(
        AppendRequest.functionStatement(
          source: content,
          functionName: functionName,
          memberSource: registration,
        ),
      );
      content = result.source;
    }

    return content;
  }
}
