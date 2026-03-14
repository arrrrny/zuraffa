import 'dart:io';
import '../../../core/plugin_system/capability.dart';
import '../feature_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';
import '../../../config/zfa_config.dart';
import '../../usecase/usecase_plugin.dart';
import '../../repository/repository_plugin.dart';
import '../../view/view_plugin.dart';
import '../../presenter/presenter_plugin.dart';
import '../../controller/controller_plugin.dart';
import '../../state/state_plugin.dart';
import '../../route/route_plugin.dart';
import '../../di/di_plugin.dart';
import '../../mock/mock_plugin.dart';
import '../../test/test_plugin.dart';
import '../../datasource/datasource_plugin.dart';
import '../../service/service_plugin.dart';
import '../../provider/provider_plugin.dart';
import '../../../core/generator_options.dart';

class ScaffoldFeatureCapability implements ZuraffaCapability {
  final FeaturePlugin plugin;

  ScaffoldFeatureCapability(this.plugin);

  @override
  String get name => 'scaffold';

  @override
  String get description =>
      'Scaffold a full feature set (VPC, Repo, UseCase, etc.)';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Name of the feature (e.g. UserProfile)',
      },
      'vpcs': {
        'type': 'boolean',
        'description': 'Generate View, Presenter, Controller, State',
      },
      'repository': {'type': 'boolean', 'description': 'Generate Repository'},
      'datasource': {
        'type': 'boolean',
        'description': 'Generate DataSource (Remote and/or Local)',
      },
      'local': {
        'type': 'boolean',
        'description': 'Generate local data source (instead of remote)',
      },
      'mock': {'type': 'boolean', 'description': 'Generate Mock data'},
      'use-mock': {
        'type': 'boolean',
        'description': 'Use mock datasources in DI registration',
      },
      'di': {
        'type': 'boolean',
        'description': 'Generate Dependency Injection setup',
      },
      'cache': {
        'type': 'boolean',
        'description': 'Enable Caching (generates local + remote datasources)',
        'default': false,
      },
      'use-service': {
        'type': 'boolean',
        'description': 'Use service and provider instead of repository and datasource',
        'default': false,
      },
      'route': {
        'type': 'boolean',
        'description': 'Generate Routing definitions',
      },
      'test': {'type': 'boolean', 'description': 'Generate Tests'},
      'usecases': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'List of custom usecases to generate',
        'default': [],
      },
      'methods': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'List of entity methods to generate',
        'default': ['get', 'update'],
      },
      'id-field': {
        'type': 'string',
        'description': 'Name of the ID field',
        'default': 'id',
      },
      'id-field-type': {
        'type': 'string',
        'description': 'Type of the ID field',
        'default': 'String',
      },
      'query-field': {
        'type': 'string',
        'description': 'Name of the query field',
        'default': 'id',
      },
      'query-field-type': {
        'type': 'string',
        'description': 'Type of the query field',
        'default': 'String',
      },
      'outputDir': {
        'type': 'string',
        'description': 'Target directory for generation',
      },
      'dryRun': {
        'type': 'boolean',
        'description': 'Run without writing files',
        'default': false,
      },
      'force': {
        'type': 'boolean',
        'description': 'Force overwrite existing files',
        'default': false,
      },
      'verbose': {
        'type': 'boolean',
        'description': 'Enable verbose logging',
        'default': false,
      },
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'files': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
  };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    final files = await _generateFiles(args, dryRun: true);

    return EffectReport(
      planId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      pluginId: plugin.id,
      capabilityName: name,
      args: args,
      changes: files
          .map((f) => Effect(file: f.path, action: f.action, diff: null))
          .toList(),
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final files = await _generateFiles(args, dryRun: false);

    return ExecutionResult(
      success: true,
      files: files.map((f) => f.path).toList(),
      data: {'generatedFiles': files},
    );
  }

  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    // Load global config
    final zfaConfig = ZfaConfig.load();

    final rawOutputDir =
        args['outputDir'] ?? zfaConfig?.defaultEntityOutput ?? 'lib/src';
    // Ensure outputDir is relative to project root and doesn't start with /
    var outputDir = rawOutputDir;
    final currentPath = Directory.current.path;
    if (outputDir.startsWith('/')) {
      // If it's an absolute path that starts with current working directory, make it relative
      if (outputDir.startsWith(currentPath)) {
        outputDir = outputDir.substring(currentPath.length);
      }
      // If it still starts with /, remove it to make it relative to project root
      if (outputDir.startsWith('/')) {
        outputDir = outputDir.substring(1);
      }
    }
    if (outputDir.isEmpty) {
      outputDir = '.';
    }
    final featureName = args['name'];

    final generateVpcs = args['vpcs'] ?? true;
    final useService = args['use-service'] ?? false;
    final generateRepo = (args['repository'] ?? true) && !useService;
    final generateDataSource = (args['datasource'] ?? true) && !useService;
    final generateService = useService;
    final generateProvider = useService;
    final generateLocal = args['local'] ?? false;
    final generateMock =
        args['mock'] == true ||
        (zfaConfig?.mockByDefault == true && args['mock'] != false);
    final useMock = args['use-mock'] == true;
    // Default to ZfaConfig setting if arg is null, otherwise default to true (if arg not provided but default in schema is true, this logic might need refinement based on how args are passed. Assuming args contains defaults from command runner if not provided)
    // Actually, args coming from execute() might not have defaults populated if not called via CommandRunner.
    // Let's assume args contains what user provided.
    // If 'di' is in args, use it. If not, use ZfaConfig.diByDefault.
    final generateDi =
        args['di'] == true ||
        (zfaConfig?.diByDefault == true && args['di'] != false);

    final enableCache = args['cache'] ?? false;
    final usecases = (args['usecases'] as List?)?.cast<String>() ?? [];
    final methods = (args['methods'] as List?)?.cast<String>() ?? [];
    // If user provided NEITHER, use default methods
    final effectiveMethods = (methods.isEmpty && usecases.isEmpty)
        ? ['get', 'update']
        : methods;

    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;
    final revert = args['revert'] ?? false;
    final generateInit = args['init'] == true;
    final appendToExisting = zfaConfig?.appendByDefault ?? false;

    final generateRoute =
        args['route'] == true ||
        (zfaConfig?.routeByDefault == true && args['route'] != false);

    final generateTest =
        args['test'] == true ||
        (zfaConfig?.testByDefault == true && args['test'] != false);

    final useZorphy = args.containsKey('zorphy')
        ? args['zorphy']
        : (zfaConfig?.zorphyByDefault ?? false);

    final idField = args['id-field'] as String? ?? 'id';
    // If id-field-type was explicitly set to "NoParams" or "null", use NoParams
    // Otherwise default to String
    final idFieldTypeRaw = args['id-field-type'];
    final idFieldType = idFieldTypeRaw == 'NoParams' || idFieldTypeRaw == 'null'
        ? 'NoParams'
        : (idFieldTypeRaw as String? ?? 'String');
    final queryField = args['query-field'] as String? ?? 'id';
    // If query-field-type was explicitly set to "NoParams" or "null", use NoParams
    // Otherwise default to String
    final queryFieldTypeRaw = args['query-field-type'];
    final queryFieldType =
        queryFieldTypeRaw == 'NoParams' || queryFieldTypeRaw == 'null'
        ? 'NoParams'
        : (queryFieldTypeRaw as String? ?? 'String');

    final allFiles = <GeneratedFile>[];

    // Repository
    if (generateRepo) {
      final options = GeneratorOptions(
        dryRun: dryRun,
        force: force,
        verbose: verbose,
      );
      final repoPlugin = RepositoryPlugin(
        outputDir: outputDir,
        options: options,
      );
      final config = GeneratorConfig(
        name: featureName,
        outputDir: outputDir,
        generateRepository: true,
        generateData: true,
        generateDataSource: generateDataSource,
        generateLocal: generateLocal,
        generateMock: generateMock,
        useMockInDi: useMock,
        generateDi: generateDi,
        enableCache: enableCache,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
        revert: revert,
        appendToExisting: appendToExisting,
        methods: effectiveMethods,
        usecases: usecases,
        idField: idField,
        idFieldType: idFieldType,
        queryField: queryField,
        queryFieldType: queryFieldType,
        useZorphy: useZorphy,
        generateInit: generateInit,
      );
      allFiles.addAll(await repoPlugin.generate(config));
    }

    // DataSources - generate both local and remote if datasource flag is enabled
    if (generateDataSource) {
      final options = GeneratorOptions(
        dryRun: dryRun,
        force: force,
        verbose: verbose,
      );
      final datasourcePlugin = DataSourcePlugin(
        outputDir: outputDir,
        options: options,
      );

      final datasourceConfig = GeneratorConfig(
        name: featureName,
        outputDir: outputDir,
        generateDataSource: generateDataSource,
        generateLocal: generateLocal,
        generateMock: generateMock,
        useMockInDi: useMock,
        methods: effectiveMethods,
        usecases: usecases,
        idField: idField,
        idFieldType: idFieldType,
        queryField: queryField,
        queryFieldType: queryFieldType,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
        revert: revert,
        generateInit: generateInit,
      );

      allFiles.addAll(await datasourcePlugin.generate(datasourceConfig));
    }

    // Service
    if (generateService) {
      final options = GeneratorOptions(
        dryRun: dryRun,
        force: force,
        verbose: verbose,
      );
      final servicePlugin = ServicePlugin(
        outputDir: outputDir,
        options: options,
      );

      final serviceConfig = GeneratorConfig(
        name: featureName,
        outputDir: outputDir,
        service: '${featureName}Service',
        generateService: true,
        useService: true,
        methods: effectiveMethods,
        usecases: usecases,
        idField: idField,
        idFieldType: idFieldType,
        queryField: queryField,
        queryFieldType: queryFieldType,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
        revert: revert,
      );

      allFiles.addAll(await servicePlugin.generate(serviceConfig));
    }

    // Provider
    if (generateProvider) {
      final options = GeneratorOptions(
        dryRun: dryRun,
        force: force,
        verbose: verbose,
      );
      final providerPlugin = ProviderPlugin(
        outputDir: outputDir,
        options: options,
      );

      final providerConfig = GeneratorConfig(
        name: featureName,
        outputDir: outputDir,
        service: '${featureName}Service',
        generateData: true,
        useService: true,
        methods: effectiveMethods,
        usecases: usecases,
        idField: idField,
        idFieldType: idFieldType,
        queryField: queryField,
        queryFieldType: queryFieldType,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
        revert: revert,
      );

      allFiles.addAll(await providerPlugin.generate(providerConfig));
    }

    // UseCases
    final options = GeneratorOptions(
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    final usecasePlugin = UseCasePlugin(outputDir: outputDir, options: options);

    if (usecases.isNotEmpty) {
      // Generate specific custom usecases
      for (final usecase in usecases) {
        final config = GeneratorConfig(
          name: usecase,
          outputDir: outputDir,
          revert: revert,
          generateUseCase: true,
          dryRun: dryRun,
          force: force,
          verbose: verbose,
        );
        allFiles.addAll(await usecasePlugin.generate(config));
      }
    } else {
      // Generate entity-based CRUD usecases
      final config = GeneratorConfig(
        name: featureName,
        outputDir: outputDir,
        useCaseType: 'entity',
        generateUseCase: true,
        useService: useService,
        repo: useService ? null : '${featureName}Repository',
        service: useService ? '${featureName}Service' : null,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
        revert: revert,
        generateMock: generateMock,
        useMockInDi: useMock,
        generateDi: generateDi,
        methods: effectiveMethods,
        idField: idField,
        idFieldType: idFieldType,
        queryField: queryField,
        queryFieldType: queryFieldType,
        useZorphy: useZorphy,
      );
      allFiles.addAll(await usecasePlugin.generate(config));
    }

    // VPC
    if (generateVpcs) {
      final options = GeneratorOptions(
        dryRun: dryRun,
        force: force,
        verbose: verbose,
      );
      // View, Presenter, Controller, State, DI
      // This requires instantiating multiple plugins.
      // For brevity, let's just do View and Controller for now as proof of concept.
      final viewPlugin = ViewPlugin(outputDir: outputDir, options: options);
      final presenterPlugin = PresenterPlugin(
        outputDir: outputDir,
        options: options,
      );
      final controllerPlugin = ControllerPlugin(
        outputDir: outputDir,
        options: options,
      );
      final statePlugin = StatePlugin(outputDir: outputDir, options: options);

      final config = GeneratorConfig(
        name: featureName,
        outputDir: outputDir,
        idField: idField,
        idFieldType: idFieldType,
        queryField: queryField,
        queryFieldType: queryFieldType,
        generateVpcs: generateVpcs,
        generateView: generateVpcs,
        generatePresenter: generateVpcs,
        generateController: generateVpcs,
        generateState: generateVpcs,
        generateMock: generateMock,
        useMockInDi: useMock,
        generateDi: generateDi,
        generateRoute: generateRoute,
        useService: useService,
        service: useService ? '${featureName}Service' : null,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
        revert: revert,
        methods: effectiveMethods,
        usecases: usecases,
        generateUseCase: false, // Don't trigger orchestrator logic in VPC
      );

      allFiles.addAll(await viewPlugin.generate(config));
      allFiles.addAll(await presenterPlugin.generate(config));
      allFiles.addAll(await controllerPlugin.generate(config));
      allFiles.addAll(await statePlugin.generate(config));
    }

    // Routes - works with or without VPCs
    if (generateRoute) {
      final options = GeneratorOptions(
        dryRun: dryRun,
        force: force,
        verbose: verbose,
      );
      final routePlugin = RoutePlugin(outputDir: outputDir, options: options);

      final routeConfig = GeneratorConfig(
        name: featureName,
        outputDir: outputDir,
        generateRoute: true,
        generateDi: generateDi,
        methods: effectiveMethods,
        usecases: usecases,
        idField: idField,
        idFieldType: idFieldType,
        queryField: queryField,
        queryFieldType: queryFieldType,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
        revert: revert,
      );

      allFiles.addAll(await routePlugin.generate(routeConfig));
    }

    // DI - works with or without VPCs
    if (generateDi) {
      final options = GeneratorOptions(
        dryRun: dryRun,
        force: force,
        verbose: verbose,
      );
      final diPlugin = DiPlugin(outputDir: outputDir, options: options);

      final diConfig = GeneratorConfig(
        name: featureName,
        outputDir: outputDir,
        generateDi: true,
        generateUseCase: true,
        useCaseType: usecases.isEmpty ? 'entity' : 'usecase',
        useService: useService,
        service: useService ? '${featureName}Service' : null,
        generateData: generateDataSource || generateProvider,
        generateRepository: generateRepo,
        generateLocal: generateLocal,
        generateMock: generateMock,
        useMockInDi: useMock,
        methods: effectiveMethods,
        usecases: usecases,
        idField: idField,
        idFieldType: idFieldType,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
        revert: revert,
      );

      allFiles.addAll(await diPlugin.generate(diConfig));
    }

    // Mock - works with or without VPCs
    if (generateMock) {
      final options = GeneratorOptions(
        dryRun: dryRun,
        force: force,
        verbose: verbose,
      );
      final mockPlugin = MockPlugin(outputDir: outputDir, options: options);

      final mockConfig = GeneratorConfig(
        name: featureName,
        outputDir: outputDir,
        generateMock: true,
        useService: useService,
        service: useService ? '${featureName}Service' : null,
        generateData: generateRepo || generateProvider,
        generateDataSource: generateDataSource,
        generateRepository: generateRepo,
        generateLocal: generateLocal,
        methods: effectiveMethods,
        usecases: usecases,
        idField: idField,
        idFieldType: idFieldType,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
        revert: revert,
      );

      allFiles.addAll(await mockPlugin.generate(mockConfig));
    }

    // Test - works with or without VPCs
    if (generateTest) {
      final options = GeneratorOptions(
        dryRun: dryRun,
        force: force,
        verbose: verbose,
      );
      final testPlugin = TestPlugin(outputDir: outputDir, options: options);

      final testConfig = GeneratorConfig(
        name: featureName,
        outputDir: outputDir,
        generateTest: true,
        generateUseCase: true,
        useCaseType: usecases.isEmpty ? 'entity' : 'usecase',
        useService: useService,
        service: useService ? '${featureName}Service' : null,
        generateData: generateRepo || generateProvider,
        generateDataSource: generateDataSource,
        generateRepository: generateRepo,
        generateLocal: generateLocal,
        methods: effectiveMethods,
        usecases: usecases,
        idField: idField,
        idFieldType: idFieldType,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
        revert: revert,
      );

      allFiles.addAll(await testPlugin.generate(testConfig));
    }

    return allFiles;
  }
}
