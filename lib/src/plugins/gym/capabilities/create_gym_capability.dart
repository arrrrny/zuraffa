import '../../../core/plugin_system/capability.dart';
import '../gym_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';

/// Mirrors [CreateTestCapability]: exposes the gym plugin's `create`
/// capability so the kernel (and the `zfa gym create` subcommand) can
/// plan + execute gym artifact generation through the standard capability
/// contract.
class CreateGymCapability implements ZuraffaCapability {
  final GymPlugin plugin;

  CreateGymCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create a Gym';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Name of the gym target (entity or feature)',
      },
      'domain': {
        'type': 'string',
        'description': 'Domain folder for the gym target',
        'default': 'general',
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
    final outputDir = plugin.outputDir;
    final domain = args['domain'] ?? 'general';
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    // Mirror CreateTestCapability: try to infer the config from an existing
    // usecase file so the gym brief references the real dependencies. If no
    // usecase is found, fall back to a name-only config.
    final analyzed = await plugin.buildConfigFromUseCase(
      name,
      outputDir,
      domain,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    final config =
        analyzed ??
        GeneratorConfig(
          name: name,
          outputDir: outputDir,
          domain: domain,
          generateGym: true,
          dryRun: dryRun,
          force: force,
          verbose: verbose,
        );

    return await plugin.generate(config);
  }
}
