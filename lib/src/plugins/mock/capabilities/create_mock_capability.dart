import '../../../core/plugin_system/capability.dart';
import '../mock_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';

class CreateMockCapability implements ZuraffaCapability {
  final MockPlugin plugin;

  CreateMockCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create a Mock';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': 'Name of the mock target'},
      'outputDir': {
        'type': 'string',
        'description': 'Directory to output the file',
        'default': 'lib/src',
      },
      'data-only': {
        'type': 'boolean',
        'description': 'Generate mock data only',
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
      'service': {
        'type': 'string',
        'description': 'Service name for mock provider',
      },
      'domain': {
        'type': 'string',
        'description': 'Domain folder for the mock provider',
      },
      'params': {
        'type': 'string',
        'description': 'Parameter type for mock methods',
      },
      'returns': {
        'type': 'string',
        'description': 'Return type for mock methods',
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
    final dataOnly = args['data-only'] ?? false;
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;
    final service = args['service'];
    final domain = args['domain'];
    final params = args['params'];
    final returns = args['returns'];

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      service: service,
      domain: domain,
      paramsType: params,
      returnsType: returns,
      generateMock: !dataOnly,
      generateMockDataOnly: dataOnly,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return await plugin.generate(config);
  }
}
