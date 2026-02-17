import '../../../core/plugin_system/capability.dart';
import '../usecase_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';

class CreateUseCaseCapability implements ZuraffaCapability {
  final UseCasePlugin plugin;

  CreateUseCaseCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create a Clean Architecture UseCase';

  @override
  JsonSchema get inputSchema => {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Name of the usecase (e.g. Login)'
          },
          'type': {
            'type': 'string',
            'enum': ['entity', 'custom', 'stream'],
            'default': 'entity'
          },
          'methods': {
            'type': 'array',
            'items': {'type': 'string'},
            'default': ['get', 'list', 'create', 'update', 'delete']
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
        'required': ['name']
      };

  @override
  JsonSchema get outputSchema => {
        'type': 'object',
        'properties': {
          'files': {
            'type': 'array',
            'items': {'type': 'string'}
          }
        }
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
          .map((f) => Effect(
                file: f.path,
                action: f.action,
                diff: null,
              ))
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

  Future<List<GeneratedFile>> _generateFiles(Map<String, dynamic> args, {required bool dryRun}) async {
    final name = args['name'];
    final type = args['type'] ?? 'entity';
    final useCaseType = type == 'stream' ? 'stream' : 'future';
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    final config = GeneratorConfig(
      name: name,
      useCaseType: useCaseType,
      methods: (args['methods'] as List<dynamic>?)?.cast<String>() ??
          ['get', 'list', 'create', 'update', 'delete'],
      outputDir: args['outputDir'] ?? 'lib/src',
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return await plugin.generate(config);
  }
}
