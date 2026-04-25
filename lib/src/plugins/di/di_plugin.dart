import 'package:args/command_runner.dart';
import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../commands/modular_di_command.dart';
import '../../core/ast/append_executor.dart';
import '../../core/ast/strategies/append_strategy.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/context/file_system.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import '../../utils/string_utils.dart';
import 'builders/registration_builder.dart';
import 'builders/service_locator_builder.dart';
import 'capabilities/create_di_capability.dart';
import 'capabilities/register_capability.dart';
import 'detectors/registration_detector.dart';

/// Configures dependency injection registrations for generated code.
class DiPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  final RegistrationBuilder registrationBuilder;
  final RegistrationDetector registrationDetector;
  final AppendExecutor appendExecutor;
  final ServiceLocatorBuilder serviceLocatorBuilder;
  final FileSystem fileSystem;

  /// Creates a [DiPlugin].
  DiPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.registrationBuilder = const RegistrationBuilder(),
    this.registrationDetector = const RegistrationDetector(),
    this.appendExecutor = const AppendExecutor(),
    this.serviceLocatorBuilder = const ServiceLocatorBuilder(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create();

  @override
  List<ZuraffaCapability> get capabilities => [
    CreateDiCapability(this),
    RegisterCapability(this),
  ];

  @override
  Command createCommand() => ModularDiCommand(this);

  @override
  String get id => 'di';

  @override
  String get name => 'DI Plugin';

  @override
  String get version => '1.0.0';

  @override
  String? get configKey => 'diByDefault';

  @override
  List<String> get runAfter => [
    'usecase',
    'repository',
    'service',
    'datasource',
    'provider',
    'view',
    'presenter',
    'controller',
  ];

  @override
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'use-mock': {
        'type': 'boolean',
        'default': false,
        'description': 'Use mock providers in DI',
      },
      'framework': {
        'type': 'string',
        'enum': ['get_it'],
        'default': 'get_it',
      },
    },
  };

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      methods: context.data['methods']?.cast<String>().toList() ?? [],
      domain: context.data['domain'],
      repo: context.data['repo'],
      service: context.data['service'],
      usecases: context.data['usecases']?.cast<String>().toList() ?? [],
      generateDi: true,
      useMockInDi: context.get<bool>('use-mock') ?? false,
      diFramework: context.get<String>('framework') ?? 'get_it',
      generateUseCase:
          context.data['usecase'] == true ||
          context.data['generateUseCase'] == true,
      generateRepository:
          context.data['repository'] == true ||
          context.data['generateRepository'] == true,
      generateDataSource:
          context.data['datasource'] == true ||
          context.data['generateDataSource'] == true,
      generateData:
          context.data['data'] == true || context.data['generateData'] == true,
      generateService:
          context.data['service'] == true ||
          context.data['generateService'] == true,
      useService:
          context.data['use-service'] == true ||
          context.data['useService'] == true,
      enableCache:
          context.data['cache'] == true || context.data['enableCache'] == true,
      noEntity: context.data['no-entity'] == true,
    );

    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    if (!config.generateDi && !config.revert) {
      return [];
    }

    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose ||
        config.revert != options.revert) {
      final delegator = DiPlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
          revert: config.revert,
        ),
        registrationBuilder: registrationBuilder,
        registrationDetector: registrationDetector,
        appendExecutor: appendExecutor,
        serviceLocatorBuilder: serviceLocatorBuilder,
        fileSystem: context?.fileSystem,
      );
      return delegator.generate(config, context: context);
    }

    final fs = context?.fileSystem ?? fileSystem;
    final files = <GeneratedFile>[];

    if (config.generateUseCase) {
      files.addAll(await _generateUseCaseDIFiles(config, fs));
    }

    if (!config.hasService && !config.isOrchestrator) {
      if (config.generateDataSource || config.generateData) {
        if (config.enableCache) {
          files.add(await _generateRemoteDataSourceDI(config, fs));
          files.add(await _generateLocalDataSourceDI(config, fs));
        } else if (config.useMockInDi) {
          files.add(await _generateMockDataSourceDI(config, fs));
        } else if (config.generateLocal) {
          files.add(await _generateLocalDataSourceDI(config, fs));
        } else {
          files.add(await _generateRemoteDataSourceDI(config, fs));
        }
      }

      if (config.generateRepository || config.generateData) {
        files.add(await _generateRepositoryDI(config, fs));
      }

      if (config.generateMock &&
          !config.generateMockDataOnly &&
          (config.generateData || config.generateDataSource)) {
        files.add(await _generateMockDataSourceDI(config, fs));
      }
    }

    if (config.hasService && (config.generateService || config.generateData)) {
      final serviceFile = await _generateServiceDI(config, fs);
      if (serviceFile != null) {
        files.add(serviceFile);
      }

      if (config.generateData) {
        if (config.useMockInDi) {
          final mockProviderFile = await _generateMockProviderDI(config, fs);
          if (mockProviderFile != null) {
            files.add(mockProviderFile);
          }
        } else {
          final providerFile = await _generateProviderDI(config, fs);
          if (providerFile != null) {
            files.add(providerFile);
          }
        }
      }
    }

    final indexFiles = await _regenerateIndexFiles(
      files,
      revert: config.revert,
      fileSystem: fs,
    );
    files.addAll(indexFiles);

    final serviceLocatorFile = await _generateServiceLocator(
      revert: config.revert,
      fileSystem: fs,
    );
    if (serviceLocatorFile != null) {
      files.add(serviceLocatorFile);
    }

    return files;
  }

  Future<GeneratedFile> _generateRemoteDataSourceDI(
    GeneratorConfig config,
    FileSystem fs,
  ) async {
    final baseName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    final baseSnake = StringUtils.camelToSnake(baseName);
    final dataSourceName = '${baseName}RemoteDataSource';
    final fileName = '${baseSnake}_remote_datasource_di.dart';
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
        'package:zuraffa/zuraffa.dart',
        '../../data/datasources/$baseSnake/${baseSnake}_remote_datasource.dart',
      ],
      body: Block((b) => b..statements.add(registrationCall.statement)),
    );

    return FileUtils.writeFile(
      diPath,
      content,
      'di_datasource',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fs,
    );
  }

  Future<GeneratedFile> _generateLocalDataSourceDI(
    GeneratorConfig config,
    FileSystem fs,
  ) async {
    final baseName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    final baseSnake = StringUtils.camelToSnake(baseName);
    final dataSourceName = '${baseName}LocalDataSource';
    final fileName = '${baseSnake}_local_datasource_di.dart';
    final diPath = path.join(outputDir, 'di', 'datasources', fileName);

    final imports = <String>[
      'package:zuraffa/zuraffa.dart',
      '../../data/datasources/$baseSnake/${baseSnake}_local_datasource.dart',
    ];

    Expression constructorCall;
    if (config.cacheStorage == 'hive' || config.generateLocal) {
      imports.add('package:hive_ce_flutter/hive_ce_flutter.dart');
      imports.add('../../domain/entities/$baseSnake/$baseSnake.dart');
      final hasListMethod =
          config.methods.contains('getList') ||
          config.methods.contains('watchList');
      final boxName = hasListMethod ? '${baseSnake}s' : baseSnake;
      final boxCall = refer(
        'Hive',
      ).property('box').call([literalString(boxName)], {}, [refer(baseName)]);
      constructorCall = refer(dataSourceName).call([boxCall]);
    } else {
      constructorCall = refer(dataSourceName).call([]);
    }
    final registrationCall =
        (config.cacheStorage == 'hive' || config.generateLocal)
        ? refer('getIt')
              .property('registerSingletonAsync')
              .call(
                [
                  Method(
                    (m) => m
                      ..modifier = MethodModifier.async
                      ..body = Block((b) {
                        final hasListMethod =
                            config.methods.contains('getList') ||
                            config.methods.contains('watchList');
                        final boxName = hasListMethod
                            ? '${baseSnake}s'
                            : baseSnake;
                        final boxVar = 'box';
                        b.statements.add(
                          declareFinal(boxVar)
                              .assign(
                                refer('Hive')
                                    .property('openBox')
                                    .call(
                                      [literalString(boxName)],
                                      {},
                                      [refer(baseName)],
                                    )
                                    .awaited,
                              )
                              .statement,
                        );
                        b.statements.add(
                          refer(
                            dataSourceName,
                          ).call([refer(boxVar)]).returned.statement,
                        );
                      }),
                  ).closure,
                ],
                {},
                [refer(dataSourceName)],
              )
        : refer('getIt')
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
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fs,
    );
  }

  Future<GeneratedFile> _generateMockDataSourceDI(
    GeneratorConfig config,
    FileSystem fs,
  ) async {
    final baseName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    final baseSnake = StringUtils.camelToSnake(baseName);
    final dataSourceName = '${baseName}MockDataSource';
    final fileName = '${baseSnake}_mock_datasource_di.dart';
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
        'package:zuraffa/zuraffa.dart',
        '../../data/datasources/$baseSnake/${baseSnake}_mock_datasource.dart',
      ],
      body: Block((b) => b..statements.add(registrationCall.statement)),
    );

    return FileUtils.writeFile(
      diPath,
      content,
      'di_datasource',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fs,
    );
  }

  Future<GeneratedFile> _generateRepositoryDI(
    GeneratorConfig config,
    FileSystem fs,
  ) async {
    final baseName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    final baseSnake = StringUtils.camelToSnake(baseName);
    final repoName = '${baseName}Repository';
    final dataRepoName = 'Data${baseName}Repository';
    final fileName = '${baseSnake}_repository_di.dart';
    final diPath = path.join(outputDir, 'di', 'repositories', fileName);

    final imports = <String>[
      'package:zuraffa/zuraffa.dart',
      '../../domain/repositories/${baseSnake}_repository.dart',
      '../../data/repositories/data_${baseSnake}_repository.dart',
    ];

    Expression constructorCall;
    if (config.enableCache) {
      final remoteDataSourceName = config.useMockInDi
          ? '${baseName}MockDataSource'
          : '${baseName}RemoteDataSource';
      final localDataSourceName = '${baseName}LocalDataSource';

      final policyType = config.cachePolicy;
      final ttlMinutes = config.ttlMinutes ?? 1440;
      final policyFunctionName = policyType == 'daily'
          ? 'createDailyCachePolicy'
          : policyType == 'restart'
          ? 'createAppRestartCachePolicy'
          : 'createTtl${ttlMinutes}MinutesCachePolicy';

      final remoteImport = config.useMockInDi
          ? '../../data/datasources/$baseSnake/${baseSnake}_mock_datasource.dart'
          : '../../data/datasources/$baseSnake/${baseSnake}_remote_datasource.dart';

      imports.add(remoteImport);
      imports.add(
        '../../data/datasources/$baseSnake/${baseSnake}_local_datasource.dart',
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
        dataSourceName = '${baseName}MockDataSource';
        dataSourceImport =
            '../../data/datasources/$baseSnake/${baseSnake}_mock_datasource.dart';
      } else if (config.generateLocal) {
        dataSourceName = '${baseName}LocalDataSource';
        dataSourceImport =
            '../../data/datasources/$baseSnake/${baseSnake}_local_datasource.dart';
      } else {
        dataSourceName = '${baseName}RemoteDataSource';
        dataSourceImport =
            '../../data/datasources/$baseSnake/${baseSnake}_remote_datasource.dart';
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
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fs,
    );
  }

  Future<GeneratedFile?> _generateServiceDI(
    GeneratorConfig config,
    FileSystem fs,
  ) async {
    final serviceName = config.effectiveService;
    final serviceSnake = config.serviceSnake;
    final providerName = config.effectiveProvider;
    if (serviceName == null || serviceSnake == null || providerName == null) {
      return null;
    }
    final fileName = '${serviceSnake}_service_di.dart';
    final diPath = path.join(outputDir, 'di', 'services', fileName);

    if (config.revert) {
      return FileUtils.deleteFile(
        diPath,
        'di_service',
        dryRun: options.dryRun,
        verbose: options.verbose,
        fileSystem: fs,
      );
    }

    if (await fs.exists(diPath) && !options.force) {
      return null;
    }

    final serviceImport =
        await fs.exists(
          path.join(
            outputDir,
            'domain',
            'services',
            config.effectiveDomain,
            '${serviceSnake}_service.dart',
          ),
        )
        ? '../../domain/services/${config.effectiveDomain}/${serviceSnake}_service.dart'
        : '../../domain/services/${serviceSnake}_service.dart';

    final imports = ['package:zuraffa/zuraffa.dart', serviceImport];

    if (config.useMockInDi) {
      final mockProviderImport = config.isEntityBased || config.hasService
          ? '../../data/providers/${config.effectiveDomain}/${config.providerSnake}_mock_provider.dart'
          : '../../data/providers/${config.providerSnake}_mock_provider.dart';
      imports.add(mockProviderImport);
    } else {
      final providerImport = config.isEntityBased || config.hasService
          ? '../../data/providers/${config.effectiveDomain}/${config.providerSnake}_provider.dart'
          : '../../data/providers/${config.providerSnake}_provider.dart';
      imports.add(providerImport);
    }

    final content = registrationBuilder.buildRegistrationFile(
      functionName: 'register$serviceName',
      imports: imports,
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
                        ..body =
                            (config.useMockInDi
                                    ? refer(
                                        providerName.replaceAll(
                                          'Provider',
                                          'MockProvider',
                                        ),
                                      ).call([])
                                    : refer(
                                        'getIt',
                                      ).call([], {}, [refer(providerName)]))
                                .code,
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
      'di_service',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fs,
    );
  }

  Future<GeneratedFile?> _generateMockProviderDI(
    GeneratorConfig config,
    FileSystem fs,
  ) async {
    final providerName = config.effectiveProvider;
    final providerSnake = config.providerSnake;
    if (providerName == null || providerSnake == null) {
      return null;
    }
    final mockProviderName = providerName.replaceAll(
      'Provider',
      'MockProvider',
    );
    final mockProviderSnake = StringUtils.camelToSnake(mockProviderName);
    final fileName = '${mockProviderSnake}_di.dart';
    final diPath = path.join(outputDir, 'di', 'providers', fileName);

    if (config.revert) {
      return FileUtils.deleteFile(
        diPath,
        'di_mock_provider',
        dryRun: options.dryRun,
        verbose: options.verbose,
        fileSystem: fs,
      );
    }

    final mockProviderImport = config.isEntityBased || config.hasService
        ? '../../data/providers/${config.effectiveDomain}/$mockProviderSnake.dart'
        : '../../data/providers/$mockProviderSnake.dart';

    final content = registrationBuilder.buildRegistrationFile(
      functionName: 'register$mockProviderName',
      imports: ['package:zuraffa/zuraffa.dart', mockProviderImport],
      body: Block(
        (b) => b
          ..statements.add(
            refer('getIt').property('registerLazySingleton').call([
              Method(
                (m) => m
                  ..lambda = true
                  ..body = refer(mockProviderName).call([]).code,
              ).closure,
            ]).statement,
          ),
      ),
    );

    return FileUtils.writeFile(
      diPath,
      content,
      'di_mock_provider',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fs,
    );
  }

  Future<GeneratedFile?> _generateProviderDI(
    GeneratorConfig config,
    FileSystem fs,
  ) async {
    final providerName = config.effectiveProvider;
    final providerSnake = config.providerSnake;
    if (providerName == null || providerSnake == null) {
      return null;
    }
    final fileName = '${providerSnake}_provider_di.dart';
    final diPath = path.join(outputDir, 'di', 'providers', fileName);

    if (config.revert) {
      return FileUtils.deleteFile(
        diPath,
        'di_provider',
        dryRun: options.dryRun,
        verbose: options.verbose,
        fileSystem: fs,
      );
    }

    final providerImport = config.isEntityBased || config.hasService
        ? '../../data/providers/${config.effectiveDomain}/${providerSnake}_provider.dart'
        : '../../data/providers/${providerSnake}_provider.dart';

    final content = registrationBuilder.buildRegistrationFile(
      functionName: 'register$providerName',
      imports: ['package:zuraffa/zuraffa.dart', providerImport],
      body: Block(
        (b) => b
          ..statements.add(
            refer('getIt').property('registerLazySingleton').call([
              Method(
                (m) => m
                  ..lambda = true
                  ..body = refer(providerName).call([]).code,
              ).closure,
            ]).statement,
          ),
      ),
    );

    return FileUtils.writeFile(
      diPath,
      content,
      'di_provider',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fs,
    );
  }

  Future<List<GeneratedFile>> _generateUseCaseDIFiles(
    GeneratorConfig config,
    FileSystem fs,
  ) async {
    final files = <GeneratedFile>[];

    if (config.isOrchestrator) {
      files.add(await _generateOrchestratorUseCaseDI(config, fs));
    } else if (config.isEntityBased) {
      files.addAll(await _generateEntityUseCaseDIFiles(config, fs));
    } else if (config.isCustomUseCase) {
      files.add(await _generateCustomUseCaseDI(config, fs));
    }

    return files;
  }

  Future<GeneratedFile> _generateOrchestratorUseCaseDI(
    GeneratorConfig config,
    FileSystem fs,
  ) async {
    final className = '${config.name}UseCase';
    final classSnake = config.nameSnake;
    final domainSnake = config.effectiveDomain;
    final fileName = '${classSnake}_usecase_di.dart';
    final diPath = path.join(outputDir, 'di', 'usecases', fileName);

    final imports = {
      'package:zuraffa/zuraffa.dart',
      '../../domain/usecases/$domainSnake/${classSnake}_usecase.dart',
    };

    final usecaseParams = <Expression>[];
    for (final usecaseName in config.usecases) {
      final usecaseClassName = usecaseName.endsWith('UseCase')
          ? usecaseName
          : '${usecaseName}UseCase';

      if (usecaseClassName == className) {
        continue;
      }

      final usecaseSnake = StringUtils.camelToSnake(
        usecaseClassName.replaceAll('UseCase', ''),
      );

      final usecaseDomain = await _findUseCaseDomain(
        usecaseSnake,
        domainSnake,
        fs,
      );
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
      imports: imports.toList(),
      body: Block((b) => b..statements.add(registrationCall.statement)),
    );

    return FileUtils.writeFile(
      diPath,
      content,
      'di_usecase',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fs,
    );
  }

  Future<String> _findUseCaseDomain(
    String usecaseSnake,
    String defaultDomain,
    FileSystem fs,
  ) async {
    final usecasesDir = path.join(outputDir, 'domain', 'usecases');
    if (await fs.exists(usecasesDir)) {
      final items = await fs.list(usecasesDir);
      for (final item in items) {
        if (await fs.isDirectory(item)) {
          final useCaseFile = path.join(item, '${usecaseSnake}_usecase.dart');
          if (await fs.exists(useCaseFile)) {
            return path.basename(item);
          }
        }
      }
    }
    return defaultDomain;
  }

  Future<List<GeneratedFile>> _generateEntityUseCaseDIFiles(
    GeneratorConfig config,
    FileSystem fs,
  ) async {
    final files = <GeneratedFile>[];
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final domainSnake = config.effectiveDomain;

    final repoName = '${entityName}Repository';
    final repoSnake = entitySnake;

    final serviceName = config.effectiveService;
    final serviceSnake = config.serviceSnake;
    final useService = config.useService;

    final methods = config.methods;
    if (methods.isEmpty) return files;

    final validMethods = [
      'get',
      'list',
      'getList',
      'create',
      'update',
      'delete',
      'watch',
      'watchList',
    ];

    for (final method in methods) {
      if (!validMethods.contains(method)) continue;

      final usecaseInfo = _getUseCaseInfo(method, entityName);
      final className = usecaseInfo.className;
      final classSnake = StringUtils.camelToSnake(
        className.replaceAll('UseCase', ''),
      );
      final fileName = '${classSnake}_usecase_di.dart';
      final diPath = path.join(outputDir, 'di', 'usecases', fileName);

      final imports = <String>[
        'package:zuraffa/zuraffa.dart',
        '../../domain/usecases/$domainSnake/${classSnake}_usecase.dart',
      ];

      if (useService && serviceName != null && serviceSnake != null) {
        final serviceImport =
            await fs.exists(
              path.join(
                outputDir,
                'domain',
                'services',
                domainSnake,
                '${serviceSnake}_service.dart',
              ),
            )
            ? '../../domain/services/$domainSnake/${serviceSnake}_service.dart'
            : '../../domain/services/${serviceSnake}_service.dart';
        imports.add(serviceImport);
      } else {
        imports.add('../../domain/repositories/${repoSnake}_repository.dart');
      }

      final constructorCall = refer(className).call([
        refer('getIt').call([], {}, [
          refer(useService && serviceName != null ? serviceName : repoName),
        ]),
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
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          revert: config.revert,
          fileSystem: fs,
        ),
      );
    }

    return files;
  }

  Future<GeneratedFile> _generateCustomUseCaseDI(
    GeneratorConfig config,
    FileSystem fs,
  ) async {
    final className = '${config.name}UseCase';
    final classSnake = config.nameSnake;
    final domainSnake = config.effectiveDomain;
    final fileName = '${classSnake}_usecase_di.dart';
    final diPath = path.join(outputDir, 'di', 'usecases', fileName);

    final imports = {
      'package:zuraffa/zuraffa.dart',
      '../../domain/usecases/$domainSnake/${classSnake}_usecase.dart',
    };

    final constructorParams = <Expression>[];

    final effectiveRepos = config.effectiveRepos;
    if (effectiveRepos.isNotEmpty) {
      for (final repo in effectiveRepos) {
        final repoSnake = StringUtils.camelToSnake(
          repo.replaceAll('Repository', ''),
        );
        imports.add('../../domain/repositories/${repoSnake}_repository.dart');
        constructorParams.add(refer('getIt').call([], {}, [refer(repo)]));
      }
    }

    final serviceName = config.effectiveService;
    if (serviceName != null) {
      final serviceSnake = config.serviceSnake;
      if (serviceSnake != null) {
        final serviceImport =
            await fs.exists(
              path.join(
                outputDir,
                'domain',
                'services',
                domainSnake,
                '${serviceSnake}_service.dart',
              ),
            )
            ? '../../domain/services/$domainSnake/${serviceSnake}_service.dart'
            : '../../domain/services/${serviceSnake}_service.dart';

        imports.add(serviceImport);
        constructorParams.add(
          refer('getIt').call([], {}, [refer(serviceName)]),
        );
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
      imports: imports.toList(),
      body: Block((b) => b..statements.add(registrationCall.statement)),
    );

    return FileUtils.writeFile(
      diPath,
      content,
      'di_usecase',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fs,
    );
  }

  ({String className, String methodPrefix}) _getUseCaseInfo(
    String method,
    String entityName,
  ) {
    return switch (method) {
      'get' => (className: 'Get${entityName}UseCase', methodPrefix: 'get'),
      'list' => (
        className: 'Get${entityName}ListUseCase',
        methodPrefix: 'getList',
      ),
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
      'toggle' => (
        className: 'Toggle${entityName}UseCase',
        methodPrefix: 'toggle',
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

  Future<List<GeneratedFile>> _regenerateIndexFiles(
    List<GeneratedFile> files, {
    bool revert = false,
    required FileSystem fileSystem,
  }) async {
    final indexFiles = <GeneratedFile>[];

    void addIfNotNull(GeneratedFile? f) {
      if (f != null) indexFiles.add(f);
    }

    addIfNotNull(
      await _regenerateIndexFile(
        'usecases',
        'UseCases',
        files,
        revert: revert,
        fileSystem: fileSystem,
      ),
    );
    addIfNotNull(
      await _regenerateIndexFile(
        'datasources',
        'DataSources',
        files,
        revert: revert,
        fileSystem: fileSystem,
      ),
    );
    addIfNotNull(
      await _regenerateIndexFile(
        'repositories',
        'Repositories',
        files,
        revert: revert,
        fileSystem: fileSystem,
      ),
    );
    addIfNotNull(
      await _regenerateIndexFile(
        'services',
        'Services',
        files,
        revert: revert,
        fileSystem: fileSystem,
      ),
    );
    addIfNotNull(
      await _regenerateIndexFile(
        'providers',
        'Providers',
        files,
        revert: revert,
        fileSystem: fileSystem,
      ),
    );

    final allFiles = [...files, ...indexFiles];
    addIfNotNull(
      await _regenerateMainIndex(
        allFiles,
        revert: revert,
        fileSystem: fileSystem,
      ),
    );

    return indexFiles;
  }

  Future<GeneratedFile?> _regenerateIndexFile(
    String folder,
    String label,
    List<GeneratedFile> files, {
    bool revert = false,
    required FileSystem fileSystem,
  }) async {
    final dirPath = path.join(outputDir, 'di', folder);
    final indexPath = path.join(dirPath, 'index.dart');

    var registrations = await registrationDetector.detectRegistrations(
      dirPath,
      pendingFiles: files,
      fileSystem: fileSystem,
    );

    final deletedPaths = files
        .where((f) => f.action == 'deleted')
        .map((f) => f.path)
        .toSet();

    if (registrations.isEmpty) {
      if (deletedPaths.isNotEmpty) {
        return FileUtils.deleteFile(
          indexPath,
          'di_index',
          dryRun: options.dryRun,
          verbose: options.verbose,
          fileSystem: fileSystem,
        );
      }
      return null;
    }

    final importPaths = [
      'package:zuraffa/zuraffa.dart',
      ...registrations.map((r) => r.fileName),
    ];
    final registrationCalls = registrations
        .map((r) => '${r.functionName}(getIt);')
        .toList();
    final functionName = 'registerAll$label';

    String content;
    if (await fileSystem.exists(indexPath) && !options.force && !revert) {
      content = _updateIndexFile(
        existingContent: await fileSystem.read(indexPath),
        importPaths: importPaths,
        exportPaths: const [],
        functionName: functionName,
        registrationCalls: registrationCalls,
        revert: false,
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

    return FileUtils.writeFile(
      indexPath,
      content,
      'di_index',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      fileSystem: fileSystem,
    );
  }

  Future<GeneratedFile?> _regenerateMainIndex(
    List<GeneratedFile> files, {
    bool revert = false,
    required FileSystem fileSystem,
  }) async {
    final mainIndexPath = path.join(outputDir, 'di', 'index.dart');

    final usecasesDir = path.join(outputDir, 'di', 'usecases');
    final datasourcesDir = path.join(outputDir, 'di', 'datasources');
    final repositoriesDir = path.join(outputDir, 'di', 'repositories');
    final servicesDir = path.join(outputDir, 'di', 'services');
    final providersDir = path.join(outputDir, 'di', 'providers');

    final deletedPaths = files
        .where((f) => f.action == 'deleted')
        .map((f) => f.path)
        .toSet();

    Future<bool> hasIndex(String dir) async {
      final indexPath = path.join(dir, 'index.dart');
      if (deletedPaths.contains(indexPath)) return false;

      final isJustGenerated = files.any(
        (f) =>
            f.path == indexPath &&
            (f.action == 'created' || f.action == 'updated'),
      );
      if (isJustGenerated) return true;

      return fileSystem.exists(indexPath);
    }

    final exportPaths = <String>[];
    final importPaths = <String>['package:zuraffa/zuraffa.dart'];
    final registrationCalls = <String>[];

    if (await hasIndex(usecasesDir)) {
      exportPaths.add('usecases/index.dart');
      importPaths.add('usecases/index.dart');
      registrationCalls.add('registerAllUseCases(getIt);');
    }

    if (await hasIndex(datasourcesDir)) {
      exportPaths.add('datasources/index.dart');
      importPaths.add('datasources/index.dart');
      registrationCalls.add('registerAllDataSources(getIt);');
    }

    if (await hasIndex(repositoriesDir)) {
      exportPaths.add('repositories/index.dart');
      importPaths.add('repositories/index.dart');
      registrationCalls.add('registerAllRepositories(getIt);');
    }

    if (await hasIndex(servicesDir)) {
      exportPaths.add('services/index.dart');
      importPaths.add('services/index.dart');
      registrationCalls.add('registerAllServices(getIt);');
    }

    if (await hasIndex(providersDir)) {
      exportPaths.add('providers/index.dart');
      importPaths.add('providers/index.dart');
      registrationCalls.add('registerAllProviders(getIt);');
    }

    if (registrationCalls.isEmpty) {
      if (deletedPaths.isNotEmpty &&
          (await fileSystem.exists(mainIndexPath) ||
              files.any((f) => f.path == mainIndexPath))) {
        return FileUtils.deleteFile(
          mainIndexPath,
          'di_main_index',
          dryRun: options.dryRun,
          verbose: options.verbose,
          fileSystem: fileSystem,
        );
      }
      return null;
    }

    String content;
    if (await fileSystem.exists(mainIndexPath) && !options.force && !revert) {
      content = _updateIndexFile(
        existingContent: await fileSystem.read(mainIndexPath),
        importPaths: importPaths,
        exportPaths: exportPaths,
        functionName: 'setupDependencies',
        registrationCalls: registrationCalls,
        revert: false,
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

    return FileUtils.writeFile(
      mainIndexPath,
      content,
      'di_main_index',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      fileSystem: fileSystem,
    );
  }

  String _updateIndexFile({
    required String existingContent,
    required List<String> importPaths,
    required List<String> exportPaths,
    required String functionName,
    required List<String> registrationCalls,
    bool revert = false,
  }) {
    var content = existingContent;

    for (final exportPath in exportPaths) {
      final request = AppendRequest.export(
        source: content,
        exportPath: exportPath,
      );
      final result = revert
          ? appendExecutor.undo(request)
          : appendExecutor.execute(request);
      content = result.source;
    }

    for (final importPath in importPaths) {
      final request = AppendRequest.import(
        source: content,
        importPath: importPath,
      );
      final result = revert
          ? appendExecutor.undo(request)
          : appendExecutor.execute(request);
      content = result.source;
    }

    for (final registration in registrationCalls) {
      final request = AppendRequest.functionStatement(
        source: content,
        functionName: functionName,
        memberSource: registration,
      );
      final result = revert
          ? appendExecutor.undo(request)
          : appendExecutor.execute(request);
      content = result.source;
    }

    return content;
  }

  Future<GeneratedFile?> _generateServiceLocator({
    bool revert = false,
    required FileSystem fileSystem,
  }) async {
    final serviceLocatorPath = path.join(
      outputDir,
      'di',
      'service_locator.dart',
    );

    if (revert) {
      if (options.verbose) {
        print('  ⏭ Skipping deletion of shared file: $serviceLocatorPath');
      }
      return null;
    }

    if (await fileSystem.exists(serviceLocatorPath) && !options.force) {
      return null;
    }

    final content = serviceLocatorBuilder.build();

    return FileUtils.writeFile(
      serviceLocatorPath,
      content,
      'di_service_locator',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: false,
      fileSystem: fileSystem,
    );
  }
}
