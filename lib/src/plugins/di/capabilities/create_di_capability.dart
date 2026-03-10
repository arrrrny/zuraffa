import '../../../core/plugin_system/capability.dart';
import '../di_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';

class CreateDiCapability implements ZuraffaCapability {
  final DiPlugin plugin;

  CreateDiCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create DI registrations';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Name of the entity (e.g. Product)',
      },
      'outputDir': {
        'type': 'string',
        'description': 'Directory to output the file',
        'default': 'lib/src',
      },
      'domain': {
        'type': 'string',
        'description': 'Domain name for the usecase/entity',
      },
      'service': {
        'type': 'string',
        'description': 'Service name for custom usecases',
      },
      'repo': {
        'type': 'string',
        'description': 'Repository name for custom usecases',
      },
      'useMock': {
        'type': 'boolean',
        'description': 'Use mock implementation for datasources',
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
    final domain = args['domain'];
    final service = args['service'];
    final repo = args['repo'];
    final useMock = args['useMock'] ?? false;
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      domain: domain,
      service: service,
      repo: repo,
      generateDi: true,
      useMockInDi: useMock,
      generateData:
          useMock, // Needed to trigger mock datasource/provider generation
      generateRepository: useMock, // Needed to trigger repository DI generation
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return await plugin.generate(config);
  }
}
