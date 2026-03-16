import 'dart:io';

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
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Product'));
/// ```
class DiPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  final RegistrationBuilder registrationBuilder;
  final RegistrationDetector registrationDetector;
  final AppendExecutor appendExecutor;
  final ServiceLocatorBuilder serviceLocatorBuilder;

  /// Creates a [DiPlugin].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param options Generation flags for writing behavior and logging.
  /// @param dryRun Deprecated: use [options].
  /// @param force Deprecated: use [options].
  /// @param verbose Deprecated: use [options].
  /// @param registrationBuilder Optional registration builder override.
  /// @param registrationDetector Optional registration detector override.
  /// @param appendExecutor Optional append executor override.
  /// @param serviceLocatorBuilder Optional service locator builder override.
  DiPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.registrationBuilder = const RegistrationBuilder(),
    this.registrationDetector = const RegistrationDetector(),
    this.appendExecutor = const AppendExecutor(),
    this.serviceLocatorBuilder = const ServiceLocatorBuilder(),
  });

  @override
  List<ZuraffaCapability> get capabilities => [
    CreateDiCapability(this),
    RegisterCapability(this),
  ];

  @override
  Command createCommand() => ModularDiCommand(this);

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
    // Use flags from config if they differ from instance (though this plugin uses instance fields directly in methods)
    // To support dynamic flags without refactoring all internal methods, we need to ensure this instance
    // or a new instance is used with correct flags.
    // However, DiPlugin methods access `this.dryRun`, `this.outputDir` etc.
    // If we want to respect config flags, we should create a new instance or refactor methods to take flags.
    // Given the complexity, let's create a new instance with correct flags and delegate.

    // Avoid recursion if flags match (primitive check, or just check if this is a "delegator")
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
      );
      return delegator.generate(config);
    }

    final files = <GeneratedFile>[];

    // Generate UseCase DI files for all UseCase types
    if (config.generateUseCase) {
      files.addAll(await _generateUseCaseDIFiles(config));
    }

    // Only generate DataSource/Repository DI if NOT using a Service/Provider pattern
    if (!config.hasService && !config.isOrchestrator) {
      if (config.generateDataSource || config.generateData) {
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

      if (config.generateRepository || config.generateData) {
        files.add(await _generateRepositoryDI(config));
      }

      if (config.generateMock &&
          !config.generateMockDataOnly &&
          (config.generateData || config.generateDataSource)) {
        files.add(await _generateMockDataSourceDI(config));
      }
    }

    if (config.hasService && (config.generateService || config.generateData)) {
      final serviceFile = await _generateServiceDI(config);
      if (serviceFile != null) {
        files.add(serviceFile);
      }

      if (config.generateData) {
        if (config.useMockInDi) {
          final mockProviderFile = await _generateMockProviderDI(config);
          if (mockProviderFile != null) {
            files.add(mockProviderFile);
          }
        } else {
          final providerFile = await _generateProviderDI(config);
          if (providerFile != null) {
            files.add(providerFile);
          }
        }
      }
    }

    final indexFiles = await _regenerateIndexFiles(
      files,
      revert: config.revert,
    );
    files.addAll(indexFiles);

    final serviceLocatorFile = await _generateServiceLocator(
      revert: config.revert,
    );
    if (serviceLocatorFile != null) {
      files.add(serviceLocatorFile);
    }

    return files;
  }

  Future<GeneratedFile> _generateRemoteDataSourceDI(
    GeneratorConfig config,
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
        'package:get_it/get_it.dart',
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
    );
  }

  Future<GeneratedFile> _generateLocalDataSourceDI(
    GeneratorConfig config,
  ) async {
    final baseName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    final baseSnake = StringUtils.camelToSnake(baseName);
    final dataSourceName = '${baseName}LocalDataSource';
    final fileName = '${baseSnake}_local_datasource_di.dart';
    final diPath = path.join(outputDir, 'di', 'datasources', fileName);

    final imports = <String>[
      'package:get_it/get_it.dart',
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
    );
  }

  Future<GeneratedFile> _generateMockDataSourceDI(
    GeneratorConfig config,
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
        'package:get_it/get_it.dart',
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
    );
  }

  Future<GeneratedFile> _generateRepositoryDI(GeneratorConfig config) async {
    final baseName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    final baseSnake = StringUtils.camelToSnake(baseName);
    final repoName = '${baseName}Repository';
    final dataRepoName = 'Data${baseName}Repository';
    final fileName = '${baseSnake}_repository_di.dart';
    final diPath = path.join(outputDir, 'di', 'repositories', fileName);

    final imports = <String>[
      'package:get_it/get_it.dart',
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
    );
  }

  Future<GeneratedFile?> _generateServiceDI(GeneratorConfig config) async {
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
      );
    }

    if (File(diPath).existsSync() && !options.force) {
      return null;
    }

    final serviceImport = config.isEntityBased
        ? '../../domain/services/${config.effectiveDomain}/${serviceSnake}_service.dart'
        : '../../domain/services/${serviceSnake}_service.dart';

    final imports = ['package:get_it/get_it.dart', serviceImport];

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
    );
  }

  Future<GeneratedFile?> _generateMockProviderDI(GeneratorConfig config) async {
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
      );
    }

    final mockProviderImport = config.isEntityBased || config.hasService
        ? '../../data/providers/${config.effectiveDomain}/$mockProviderSnake.dart'
        : '../../data/providers/$mockProviderSnake.dart';

    final content = registrationBuilder.buildRegistrationFile(
      functionName: 'register$mockProviderName',
      imports: ['package:get_it/get_it.dart', mockProviderImport],
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
    );
  }

  Future<GeneratedFile?> _generateProviderDI(GeneratorConfig config) async {
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
      );
    }

    final providerImport = config.isEntityBased || config.hasService
        ? '../../data/providers/${config.effectiveDomain}/${providerSnake}_provider.dart'
        : '../../data/providers/${providerSnake}_provider.dart';

    final content = registrationBuilder.buildRegistrationFile(
      functionName: 'register$providerName',
      imports: ['package:get_it/get_it.dart', providerImport],
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
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
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

    final serviceName = config.effectiveService;
    final serviceSnake = config.serviceSnake;
    final useService = config.useService;

    final methods = config.methods;
    if (methods.isEmpty) return files;

    for (final method in methods) {
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
      ];

      if (useService && serviceName != null && serviceSnake != null) {
        imports.add(
          '../../domain/services/$domainSnake/${serviceSnake}_service.dart',
        );
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
        if (config.useService) {
          imports.add(
            '../../domain/services/$domainSnake/${serviceSnake}_service.dart',
          );
        } else {
          imports.add('../../domain/services/${serviceSnake}_service.dart');
        }
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
      imports: imports,
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
  }) async {
    final indexFiles = <GeneratedFile>[];

    void addIfNotNull(GeneratedFile? f) {
      if (f != null) indexFiles.add(f);
    }

    addIfNotNull(
      await _regenerateIndexFile('usecases', 'UseCases', files, revert: revert),
    );
    addIfNotNull(
      await _regenerateIndexFile(
        'datasources',
        'DataSources',
        files,
        revert: revert,
      ),
    );
    addIfNotNull(
      await _regenerateIndexFile(
        'repositories',
        'Repositories',
        files,
        revert: revert,
      ),
    );
    addIfNotNull(
      await _regenerateIndexFile('services', 'Services', files, revert: revert),
    );
    addIfNotNull(
      await _regenerateIndexFile(
        'providers',
        'Providers',
        files,
        revert: revert,
      ),
    );

    final allFiles = [...files, ...indexFiles];
    addIfNotNull(await _regenerateMainIndex(allFiles, revert: revert));

    return indexFiles;
  }

  Future<GeneratedFile?> _regenerateIndexFile(
    String folder,
    String label,
    List<GeneratedFile> files, {
    bool revert = false,
  }) async {
    final dirPath = path.join(outputDir, 'di', folder);
    final indexPath = path.join(dirPath, 'index.dart');

    var registrations = registrationDetector.detectRegistrations(
      dirPath,
      pendingFiles: files,
    );

    // Filter out deleted files logic is now handled inside RegistrationDetector
    final deletedPaths = files
        .where((f) => f.action == 'deleted')
        .map((f) => f.path)
        .toSet();

    if (registrations.isEmpty) {
      if (deletedPaths.isNotEmpty) {
        // If we deleted files and no registrations left, delete index file
        return FileUtils.deleteFile(
          indexPath,
          'di_index',
          dryRun: options.dryRun,
          verbose: options.verbose,
        );
      }
      return null;
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
    if (File(indexPath).existsSync() && !options.force && !revert) {
      content = _updateIndexFile(
        existingContent: File(indexPath).readAsStringSync(),
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
    );
  }

  Future<GeneratedFile?> _regenerateMainIndex(
    List<GeneratedFile> files, {
    bool revert = false,
  }) async {
    final mainIndexPath = path.join(outputDir, 'di', 'index.dart');

    final usecasesDir = Directory(path.join(outputDir, 'di', 'usecases'));
    final datasourcesDir = Directory(path.join(outputDir, 'di', 'datasources'));
    final repositoriesDir = Directory(
      path.join(outputDir, 'di', 'repositories'),
    );
    final servicesDir = Directory(path.join(outputDir, 'di', 'services'));
    final providersDir = Directory(path.join(outputDir, 'di', 'providers'));

    final deletedPaths = files
        .where((f) => f.action == 'deleted')
        .map((f) => f.path)
        .toSet();

    bool hasIndex(Directory dir) {
      final indexPath = path.join(dir.path, 'index.dart');
      if (deletedPaths.contains(indexPath)) return false;

      final isJustGenerated = files.any(
        (f) =>
            f.path == indexPath &&
            (f.action == 'created' || f.action == 'updated'),
      );
      if (isJustGenerated) return true;

      return File(indexPath).existsSync();
    }

    final exportPaths = <String>[];
    final importPaths = <String>['package:get_it/get_it.dart'];
    final registrationCalls = <String>[];

    if (hasIndex(usecasesDir)) {
      exportPaths.add('usecases/index.dart');
      importPaths.add('usecases/index.dart');
      registrationCalls.add('registerAllUseCases(getIt);');
    }

    if (hasIndex(datasourcesDir)) {
      exportPaths.add('datasources/index.dart');
      importPaths.add('datasources/index.dart');
      registrationCalls.add('registerAllDataSources(getIt);');
    }

    if (hasIndex(repositoriesDir)) {
      exportPaths.add('repositories/index.dart');
      importPaths.add('repositories/index.dart');
      registrationCalls.add('registerAllRepositories(getIt);');
    }

    if (hasIndex(servicesDir)) {
      exportPaths.add('services/index.dart');
      importPaths.add('services/index.dart');
      registrationCalls.add('registerAllServices(getIt);');
    }

    if (hasIndex(providersDir)) {
      exportPaths.add('providers/index.dart');
      importPaths.add('providers/index.dart');
      registrationCalls.add('registerAllProviders(getIt);');
    }

    if (registrationCalls.isEmpty) {
      if (deletedPaths.isNotEmpty &&
          (File(mainIndexPath).existsSync() ||
              files.any((f) => f.path == mainIndexPath))) {
        // If we have deleted files, check if main index becomes empty (no registrations).
        // However, main index might contain other things? Usually just exports and registerAll calls.
        // If registrationCalls is empty, it means no sub-modules.
        // We should probably delete main index if it exists.
        return FileUtils.deleteFile(
          mainIndexPath,
          'di_main_index',
          dryRun: options.dryRun,
          verbose: options.verbose,
        );
      }
      return null;
    }

    String content;
    if (File(mainIndexPath).existsSync() && !options.force && !revert) {
      content = _updateIndexFile(
        existingContent: File(mainIndexPath).readAsStringSync(),
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

  Future<GeneratedFile?> _generateServiceLocator({bool revert = false}) async {
    final serviceLocatorPath = path.join(
      outputDir,
      'di',
      'service_locator.dart',
    );

    // Skip deletion of shared service locator file during revert
    if (revert) {
      if (options.verbose) {
        print('  ⏭ Skipping deletion of shared file: $serviceLocatorPath');
      }
      return null;
    }

    final file = File(serviceLocatorPath);
    if (file.existsSync() && !options.force) {
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
      revert: false, // Never revert shared file
    );
  }
}
