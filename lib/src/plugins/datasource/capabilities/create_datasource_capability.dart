import '../../../core/plugin_system/capability.dart';
import '../datasource_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';

class CreateDataSourceCapability implements ZuraffaCapability {
  final DataSourcePlugin plugin;

  CreateDataSourceCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create a Data Source';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': 'Name of the data source'},
      'outputDir': {
        'type': 'string',
        'description': 'Directory to output the file',
        'default': 'lib/src',
      },
      'local': {
        'type': 'boolean',
        'description': 'Generate local data source (instead of remote)',
        'default': false,
      },
      'cache': {
        'type': 'boolean',
        'description': 'Enable caching',
        'default': false,
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
    final files = await _generateFiles(args, dryRun: args['dryRun'] ?? false);

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
    final name = args['name'];
    final outputDir = args['outputDir'] ?? 'lib/src';
    final generateLocal = args['local'] ?? false;
    final enableCache = args['cache'] ?? false;
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      generateDataSource: true,
      generateLocal: generateLocal,
      enableCache: enableCache,
      generateInit: args['init'] == true,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return await plugin.generate(config);
  }
}
