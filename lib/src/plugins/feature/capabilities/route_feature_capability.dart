import '../../../core/plugin_system/capability.dart';
import '../feature_plugin.dart';
import '../../../models/generated_file.dart';
import '../../../config/zfa_config.dart';
import '../../../core/plugin_system/plugin_manager.dart';
import '../../../core/plugin_system/plugin_registry.dart';

class RouteFeatureCapability implements ZuraffaCapability {
  final FeaturePlugin plugin;

  RouteFeatureCapability(this.plugin);

  @override
  String get name => 'route';

  @override
  String get description => 'Add routes to an existing feature';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': 'Name of the feature'},
      'methods': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'List of methods (e.g. get,create,update,delete)',
      },
      'id-field': {'type': 'string', 'default': 'id'},
      'id-field-type': {'type': 'string', 'default': 'String'},
      'query-field': {'type': 'string', 'default': 'id'},
      'query-field-type': {'type': 'string', 'default': 'String'},
      'outputDir': {'type': 'string', 'default': 'lib/src'},
      'dryRun': {'type': 'boolean', 'default': false},
      'force': {'type': 'boolean', 'default': false},
      'verbose': {'type': 'boolean', 'default': false},
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
    final projectRoot = plugin.outputDir.replaceAll('lib/src', '');

    final manager = PluginManager(
      registry: PluginRegistry.instance,
      config: zfaConfig,
      projectRoot: projectRoot,
    );

    final activePlugins = manager.resolveActivePlugins(
      explicitPluginIds: ['route'],
      argResults: null,
    );

    final context = manager.buildContext(
      name: featureName,
      argResults: null,
      activePlugins: activePlugins,
    );

    args.forEach((key, value) {
      context.data[key] = value;
    });

    context.data['dry-run'] = dryRun;
    context.data['force'] = args['force'] ?? false;
    context.data['verbose'] = args['verbose'] ?? false;
    context.data['revert'] = args['revert'] ?? false;

    return await manager.run(context, activePlugins);
  }
}
