import 'dart:io';
import '../../../core/plugin_system/capability.dart';
import '../feature_plugin.dart';
import '../../../models/generated_file.dart';
import '../../../config/zfa_config.dart';
import '../../../core/plugin_system/plugin_manager.dart';
import '../../../core/plugin_system/plugin_registry.dart';

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
        'description':
            'Use service and provider instead of repository and datasource',
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
        'default': ['get', 'update', 'toggle'],
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
      'revert': {
        'type': 'boolean',
        'description': 'Revert generated files',
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
    final featureName = args['name'] as String;
    final zfaConfig = ZfaConfig.load();
    final projectRoot = Directory.current.path;

    final manager = PluginManager(
      registry: PluginRegistry.instance,
      config: zfaConfig,
      projectRoot: projectRoot,
    );

    // Resolve explicit plugins based on flags
    final explicitIds = <String>[];
    explicitIds.add(
      'usecase',
    ); // Scaffold always generates usecases by default unless overridden
    if (args['repository'] != false) explicitIds.add('repository');
    if (args['datasource'] != false) explicitIds.add('datasource');
    if (args['use-service'] == true) explicitIds.add('service');
    if (args['vpcs'] != false) {
      explicitIds.addAll(['view', 'presenter', 'controller', 'state']);
    }
    if (args['mock'] == true) explicitIds.add('mock');
    if (args['di'] == true) explicitIds.add('di');
    if (args['route'] == true) explicitIds.add('route');
    if (args['test'] == true) explicitIds.add('test');
    if (args['cache'] == true) explicitIds.add('cache');

    final activePlugins = manager.resolveActivePlugins(
      explicitPluginIds: explicitIds,
      argResults: null,
    );

    final context = manager.buildContext(
      name: featureName,
      argResults: null,
      activePlugins: activePlugins,
      overrideDryRun: dryRun,
      overrideForce: args['force'] == true,
      overrideVerbose: args['verbose'] == true,
      overrideRevert: args['revert'] == true,
    );

    // Merge manual args into context data
    args.forEach((key, value) {
      context.data[key] = value;
    });

    // Ensure core flags are set
    context.data['dry-run'] = dryRun;
    context.data['force'] = args['force'] ?? false;
    context.data['verbose'] = args['verbose'] ?? false;
    context.data['revert'] = args['revert'] ?? false;

    return await manager.run(context, activePlugins);
  }
}
