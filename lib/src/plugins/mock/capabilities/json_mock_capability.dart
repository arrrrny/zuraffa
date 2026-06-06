import '../../../core/plugin_system/capability.dart';
import '../mock_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';

class JsonMockCapability implements ZuraffaCapability {
  final MockPlugin plugin;

  JsonMockCapability(this.plugin);

  @override
  String get name => 'json';

  @override
  String get description =>
      'Generate JSON mock data with fromJson-based Dart helpers';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Entity name to generate JSON mock data for',
      },
      'domain': {
        'type': 'string',
        'description': 'Domain folder for grouping JSON files',
      },
      'force': {
        'type': 'boolean',
        'description': 'Force overwrite existing JSON files',
        'default': false,
      },
      'dryRun': {
        'type': 'boolean',
        'description': 'Preview without writing files',
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
    final outputDir = plugin.outputDir;
    final domain = args['domain'];
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      domain: domain,
      mockJsonDomain: domain,
      generateMockJson: true,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return await plugin.generate(config);
  }
}
