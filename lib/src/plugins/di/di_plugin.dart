import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../core/ast/append_executor.dart';
import '../../core/ast/strategies/append_strategy.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import '../../utils/string_utils.dart';
import 'builders/registration_builder.dart';
import 'builders/service_locator_builder.dart';
import 'detectors/registration_detector.dart';

/// Configures dependency injection registrations for generated code.
///
/// Generates get_it registrations for:
/// - UseCases with proper lifecycle management
/// - Repositories with datasource injection
/// - Services with provider bindings
/// - Controllers with presenter injection
///
/// Supports mock/remote datasource switching via useMock flag.
///
/// Example:
/// ```dart
/// final plugin = DiPlugin(
///   outputDir: 'lib/src',
///   dryRun: false,
///   force: true,
///   verbose: false,
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Product'));
/// ```
class DiPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final RegistrationBuilder registrationBuilder;
  final RegistrationDetector registrationDetector;
  final AppendExecutor appendExecutor;
  final ServiceLocatorBuilder serviceLocatorBuilder;

  /// Creates a [DiPlugin].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param dryRun If true, files are not written.
  /// @param force If true, existing files are overwritten.
  /// @param verbose If true, logs progress to stdout.
  /// @param registrationBuilder Optional registration builder override.
  /// @param registrationDetector Optional registration detector override.
  /// @param appendExecutor Optional append executor override.
  /// @param serviceLocatorBuilder Optional service locator builder override.
  DiPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    RegistrationBuilder? registrationBuilder,
    RegistrationDetector? registrationDetector,
    AppendExecutor? appendExecutor,
    ServiceLocatorBuilder? serviceLocatorBuilder,
  }) : registrationBuilder = registrationBuilder ?? const RegistrationBuilder(),
       registrationDetector =
           registrationDetector ?? const RegistrationDetector(),
       appendExecutor = appendExecutor ?? AppendExecutor(),
       serviceLocatorBuilder =
           serviceLocatorBuilder ?? const ServiceLocatorBuilder();

  /// @returns Plugin identifier.
  @override
  String get id => 'di';

  /// @returns Plugin display name.
  @override
  String get name => 'DI Plugin';

  /// @returns Plugin version string.
  @override
  String get version => '1.0.0';

  /// Generates DI registration files for the given [config].
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @returns List of generated DI files.
  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.generateDi) {
      return [];
    }
    final files = <GeneratedFile>[];

    // Generate UseCase DI files for all UseCase types
    files.addAll(await _generateUseCaseDIFiles(config));

    if (config.generateData && !config.hasService && !config.isOrchestrator) {
      if (config.enableCache) {
        files.add(await _generateRemoteDataSourceDI(config));
        files.add(await _generateLocalDataSourceDI(config));
      } else if (config.useMockInDi) {
        files.add(await _generateMockDataSourceDI(config));
      } else if (config.generateLocal) {
        files.add(await _generateLocalDataSourceDI(config));
      } else {
        files.add(await _generateRemoteDataSourceDI(config));
      }
    }

    if ((config.generateData || config.generateRepository) &&
        !config.hasService &&
        !config.isOrchestrator) {
      files.add(await _generateRepositoryDI(config));
    }

    if (config.generateMock &&
        !config.generateMockDataOnly &&
        !config.hasService &&
        !config.isOrchestrator) {
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
    await _generateServiceLocator();

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
      body: Block((b) => b..statements.add(registrationCall.statement)),
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
    if (config.cacheStorage == 'hive' || config.generateLocal) {
      imports.add('package:hive_ce_flutter/hive_ce_flutter.dart');
      imports.add('../../domain/entities/$entitySnake/$entitySnake.dart');
      final hasListMethod =
          config.methods.contains('getList') ||
          config.methods.contains('watchList');
      final boxName = hasListMethod ? '${entitySnake}s' : entitySnake;
      final boxCall = refer(
        'Hive',
      ).property('box').call([literalString(boxName)], {}, [refer(entityName)]);
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
      body: Block((b) => b..statements.add(registrationCall.statement)),
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
      body: Block((b) => b..statements.add(registrationCall.statement)),
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
      String dataSourceName;
      String dataSourceImport;
      if (config.useMockInDi) {
        dataSourceName = '${entityName}MockDataSource';
        dataSourceImport =
            '../../data/data_sources/$entitySnake/${entitySnake}_mock_data_source.dart';
      } else if (config.generateLocal) {
        dataSourceName = '${entityName}LocalDataSource';
        dataSourceImport =
            '../../data/data_sources/$entitySnake/${entitySnake}_local_data_source.dart';
      } else {
        dataSourceName = '${entityName}RemoteDataSource';
        dataSourceImport =
            '../../data/data_sources/$entitySnake/${entitySnake}_remote_data_source.dart';
      }
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
      body: Block((b) => b..statements.add(registrationCall.statement)),
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
    final serviceName = config.effectiveService;
    final serviceSnake = config.serviceSnake;
    if (serviceName == null || serviceSnake == null) {
      return null;
    }
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
    final serviceName = config.effectiveService;
    final providerName = config.effectiveProvider;
    final providerSnake = config.providerSnake;
    final serviceSnake = config.serviceSnake;
    if (serviceName == null ||
        providerName == null ||
        providerSnake == null ||
        serviceSnake == null) {
      return null;
    }
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

  Future<List<GeneratedFile>> _generateUseCaseDIFiles(
    GeneratorConfig config,
  ) async {
    final files = <GeneratedFile>[];

    if (config.isOrchestrator) {
      files.add(await _generateOrchestratorUseCaseDI(config));
    } else if (config.isEntityBased) {
      files.addAll(await _generateEntityUseCaseDIFiles(config));
    } else if (config.isCustomUseCase) {
      files.add(await _generateCustomUseCaseDI(config));
    }

    return files;
  }

  Future<GeneratedFile> _generateOrchestratorUseCaseDI(
    GeneratorConfig config,
  ) async {
    final className = '${config.name}UseCase';
    final classSnake = config.nameSnake;
    final domainSnake = config.effectiveDomain;
    final fileName = '${classSnake}_usecase_di.dart';
    final diPath = path.join(outputDir, 'di', 'usecases', fileName);

    final imports = <String>[
      'package:get_it/get_it.dart',
      '../../domain/usecases/$domainSnake/${classSnake}_usecase.dart',
    ];

    final usecaseParams = <Expression>[];
    for (final usecaseName in config.usecases) {
      final usecaseClassName = usecaseName.endsWith('UseCase')
          ? usecaseName
          : '${usecaseName}UseCase';
      final usecaseSnake = StringUtils.camelToSnake(
        usecaseClassName.replaceAll('UseCase', ''),
      );

      // Find the actual domain for this usecase
      final usecaseDomain = _findUseCaseDomain(usecaseSnake, domainSnake);
      imports.add(
        '../../domain/usecases/$usecaseDomain/${usecaseSnake}_usecase.dart',
      );
      usecaseParams.add(refer('getIt').call([], {}, [refer(usecaseClassName)]));
    }

    final constructorCall = refer(className).call(usecaseParams);
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
          [refer(className)],
        );

    final content = registrationBuilder.buildRegistrationFile(
      functionName: 'register$className',
      imports: imports,
      body: Block((b) => b..statements.add(registrationCall.statement)),
    );

    return FileUtils.writeFile(
      diPath,
      content,
      'di_usecase',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  String _findUseCaseDomain(String usecaseSnake, String defaultDomain) {
    final usecasesDir = Directory(path.join(outputDir, 'domain', 'usecases'));
    if (usecasesDir.existsSync()) {
      for (final dir in usecasesDir.listSync()) {
        if (dir is Directory) {
          final useCaseFile = File(
            path.join(dir.path, '${usecaseSnake}_usecase.dart'),
          );
          if (useCaseFile.existsSync()) {
            return path.basename(dir.path);
          }
        }
      }
    }
    // Fallback to the default domain if not found
    return defaultDomain;
  }

  Future<List<GeneratedFile>> _generateEntityUseCaseDIFiles(
    GeneratorConfig config,
  ) async {
    final files = <GeneratedFile>[];
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final domainSnake = config.effectiveDomain;

    final repoName = '${entityName}Repository';
    final repoSnake = entitySnake;

    for (final method in config.methods) {
      final usecaseInfo = _getUseCaseInfo(method, entityName);
      final className = usecaseInfo.className;
      final classSnake = StringUtils.camelToSnake(
        className.replaceAll('UseCase', ''),
      );
      final fileName = '${classSnake}_usecase_di.dart';
      final diPath = path.join(outputDir, 'di', 'usecases', fileName);

      final imports = <String>[
        'package:get_it/get_it.dart',
        '../../domain/usecases/$domainSnake/${classSnake}_usecase.dart',
        '../../domain/repositories/${repoSnake}_repository.dart',
      ];

      final constructorCall = refer(className).call([
        refer('getIt').call([], {}, [refer(repoName)]),
      ]);

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
            [refer(className)],
          );

      final content = registrationBuilder.buildRegistrationFile(
        functionName: 'register$className',
        imports: imports,
        body: Block((b) => b..statements.add(registrationCall.statement)),
      );

      files.add(
        await FileUtils.writeFile(
          diPath,
          content,
          'di_usecase',
          force: force,
          dryRun: dryRun,
          verbose: verbose,
        ),
      );
    }

    return files;
  }

  Future<GeneratedFile> _generateCustomUseCaseDI(GeneratorConfig config) async {
    final className = '${config.name}UseCase';
    final classSnake = config.nameSnake;
    final domainSnake = config.effectiveDomain;
    final fileName = '${classSnake}_usecase_di.dart';
    final diPath = path.join(outputDir, 'di', 'usecases', fileName);

    final imports = <String>[
      'package:get_it/get_it.dart',
      '../../domain/usecases/$domainSnake/${classSnake}_usecase.dart',
    ];

    final constructorParams = <Expression>[];

    if (config.hasRepo) {
      for (final repo in config.effectiveRepos) {
        final repoSnake = StringUtils.camelToSnake(
          repo.replaceAll('Repository', ''),
        );
        imports.add('../../domain/repositories/${repoSnake}_repository.dart');
        constructorParams.add(refer('getIt').call([], {}, [refer(repo)]));
      }
    }

    if (config.hasService) {
      final serviceName = config.effectiveService;
      if (serviceName != null) {
        final serviceSnake = config.serviceSnake;
        if (serviceSnake != null) {
          imports.add('../../domain/services/${serviceSnake}_service.dart');
          constructorParams.add(
            refer('getIt').call([], {}, [refer(serviceName)]),
          );
        }
      }
    }

    final constructorCall = refer(className).call(constructorParams);
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
          [refer(className)],
        );

    final content = registrationBuilder.buildRegistrationFile(
      functionName: 'register$className',
      imports: imports,
      body: Block((b) => b..statements.add(registrationCall.statement)),
    );

    return FileUtils.writeFile(
      diPath,
      content,
      'di_usecase',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  ({String className, String methodPrefix}) _getUseCaseInfo(
    String method,
    String entityName,
  ) {
    return switch (method) {
      'get' => (className: 'Get${entityName}UseCase', methodPrefix: 'get'),
      'getList' => (
        className: 'Get${entityName}ListUseCase',
        methodPrefix: 'getList',
      ),
      'create' => (
        className: 'Create${entityName}UseCase',
        methodPrefix: 'create',
      ),
      'update' => (
        className: 'Update${entityName}UseCase',
        methodPrefix: 'update',
      ),
      'delete' => (
        className: 'Delete${entityName}UseCase',
        methodPrefix: 'delete',
      ),
      'watch' => (
        className: 'Watch${entityName}UseCase',
        methodPrefix: 'watch',
      ),
      'watchList' => (
        className: 'Watch${entityName}ListUseCase',
        methodPrefix: 'watchList',
      ),
      _ => throw ArgumentError('Unknown method: $method'),
    };
  }

  Future<void> _regenerateIndexFiles() async {
    await _regenerateIndexFile('usecases', 'UseCases');
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
          .map((r) => refer(r.functionName).call([refer('getIt')]).statement)
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

    final usecasesDir = Directory(path.join(outputDir, 'di', 'usecases'));
    final datasourcesDir = Directory(path.join(outputDir, 'di', 'datasources'));
    final repositoriesDir = Directory(
      path.join(outputDir, 'di', 'repositories'),
    );
    final servicesDir = Directory(path.join(outputDir, 'di', 'services'));
    final providersDir = Directory(path.join(outputDir, 'di', 'providers'));

    final exportPaths = <String>[];
    final importPaths = <String>['package:get_it/get_it.dart'];
    final registrationCalls = <String>[];

    if (usecasesDir.existsSync() && _hasIndexFile(usecasesDir)) {
      exportPaths.add('usecases/index.dart');
      importPaths.add('usecases/index.dart');
      registrationCalls.add('registerAllUseCases(getIt);');
    }

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
            (call) =>
                refer(call.split('(').first).call([refer('getIt')]).statement,
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

  Future<void> _generateServiceLocator() async {
    final serviceLocatorPath = path.join(
      outputDir,
      'di',
      'service_locator.dart',
    );

    final file = File(serviceLocatorPath);
    if (file.existsSync() && !force) {
      return;
    }

    final content = serviceLocatorBuilder.build();

    await FileUtils.writeFile(
      serviceLocatorPath,
      content,
      'di_service_locator',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }
}
