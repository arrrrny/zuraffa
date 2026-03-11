import '../../../core/plugin_system/capability.dart';
import '../feature_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';
import '../../../config/zfa_config.dart';
import '../../usecase/usecase_plugin.dart';
import '../../repository/repository_plugin.dart';
import '../../view/view_plugin.dart';
import '../../controller/controller_plugin.dart';
import '../../state/state_plugin.dart';
import '../../route/route_plugin.dart';
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
        'default': true,
      },
      'repository': {
        'type': 'boolean',
        'description': 'Generate Repository',
        'default': true,
      },
      'datasource': {
        'type': 'boolean',
        'description': 'Generate DataSource (Remote and/or Local)',
        'default': true,
      },
      'local': {
        'type': 'boolean',
        'description': 'Generate local data source (instead of remote)',
        'default': false,
      },
      'mock': {
        'type': 'boolean',
        'description': 'Generate Mock data',
        'default': false,
      },
      'di': {
        'type': 'boolean',
        'description': 'Generate Dependency Injection setup',
        'default': true,
      },
      'cache': {
        'type': 'boolean',
        'description': 'Enable Caching (generates local + remote datasources)',
        'default': false,
      },
      'route': {
        'type': 'boolean',
        'description': 'Generate Routing definitions',
        'default': false,
      },
      'usecases': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'List of usecases to generate',
        'default': ['get', 'update'],
      },
      'outputDir': {'type': 'string', 'default': 'lib/src'},
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
    final outputDir = args['outputDir'] ?? 'lib/src';
    final featureName = args['name'];

    // Load global config
    final zfaConfig = ZfaConfig.load();

    final generateVpcs = args['vpcs'] ?? true;
    final generateRepo = args['repository'] ?? true;
    final generateDataSource = args['datasource'] ?? true;
    final generateLocal = args['local'] ?? false;
    final generateMock = args['mock'] ?? false;
    // Default to ZfaConfig setting if arg is null, otherwise default to true (if arg not provided but default in schema is true, this logic might need refinement based on how args are passed. Assuming args contains defaults from command runner if not provided)
    // Actually, args coming from execute() might not have defaults populated if not called via CommandRunner.
    // Let's assume args contains what user provided.
    // If 'di' is in args, use it. If not, use ZfaConfig.diByDefault.
    final generateDi = args.containsKey('di')
        ? args['di']
        : (zfaConfig?.diByDefault ?? true);

    final enableCache = args['cache'] ?? false;
    final usecases = (args['usecases'] as List?)?.cast<String>() ?? [];
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;
    final revert = args['revert'] ?? false;
    final appendToExisting = zfaConfig?.appendByDefault ?? false;

    final generateRoute = args.containsKey('route')
        ? args['route']
        : (zfaConfig?.routeByDefault ?? false);

    final useZorphy = args.containsKey('zorphy')
        ? args['zorphy']
        : (zfaConfig?.zorphyByDefault ?? false);

    final idField = args['id-field'] as String? ?? 'id';
    // If id-field-type was explicitly set to null (or "null"), use NoParams
    // Otherwise default to String
    final idFieldTypeRaw = args['id-field-type'];
    final idFieldType = idFieldTypeRaw == null || idFieldTypeRaw == 'null'
        ? 'NoParams'
        : (idFieldTypeRaw as String? ?? 'String');
    final queryField = args['query-field'] as String? ?? 'id';
    // If query-field-type was explicitly set to null (or "null"), use NoParams
    // Otherwise default to String
    final queryFieldTypeRaw = args['query-field-type'];
    final queryFieldType =
        queryFieldTypeRaw == null || queryFieldTypeRaw == 'null'
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
        generateDi: generateDi,
        enableCache: enableCache,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
        revert: revert,
        appendToExisting: appendToExisting,
        methods: usecases,
        idField: idField,
        idFieldType: idFieldType,
        queryField: queryField,
        queryFieldType: queryFieldType,
        useZorphy: useZorphy,
      );
      allFiles.addAll(await repoPlugin.generate(config));
    }

    // UseCases
    if (usecases.isNotEmpty) {
      final options = GeneratorOptions(
        dryRun: dryRun,
        force: force,
        verbose: verbose,
      );
      final usecasePlugin = UseCasePlugin(
        outputDir: outputDir,
        options: options,
      );

      final config = GeneratorConfig(
        name: featureName,
        outputDir: outputDir,
        useCaseType: 'entity',
        repo: '${featureName}Repository',
        dryRun: dryRun,
        force: force,
        verbose: verbose,
        revert: revert,
        generateMock: generateMock,
        generateDi: generateDi,
        methods: usecases,
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
      final controllerPlugin = ControllerPlugin(
        outputDir: outputDir,
        options: options,
      );
      final statePlugin = StatePlugin(outputDir: outputDir, options: options);

      final config = GeneratorConfig(
        name: featureName,
        outputDir: outputDir,
        idField: 'id',
        idFieldType: 'String',
        generateVpcs: generateVpcs,
        generateView: generateVpcs,
        generateController: generateVpcs,
        generateState: generateVpcs,
        generateMock: generateMock,
        generateDi: generateDi,
        generateRoute: generateRoute,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
        revert: revert,
      );

      allFiles.addAll(await viewPlugin.generate(config));
      allFiles.addAll(await controllerPlugin.generate(config));
      allFiles.addAll(await statePlugin.generate(config));

      // Routes
      if (generateRoute) {
        final options = GeneratorOptions(
          dryRun: dryRun,
          force: force,
          verbose: verbose,
        );
        final routePlugin = RoutePlugin(outputDir: outputDir, options: options);

        // Map usecases to methods for route generation
        final routeConfig = GeneratorConfig(
          name: featureName,
          outputDir: outputDir,
          generateRoute: true,
          methods: usecases,
          dryRun: dryRun,
          force: force,
          verbose: verbose,
          revert: revert,
        );

        allFiles.addAll(await routePlugin.generate(routeConfig));
      }
    }

    return allFiles;
  }
}
