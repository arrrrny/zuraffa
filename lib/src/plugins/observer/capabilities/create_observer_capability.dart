import '../../../core/plugin_system/capability.dart';
import '../observer_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';

class CreateObserverCapability implements ZuraffaCapability {
  final ObserverPlugin plugin;

  CreateObserverCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create an Observer class';

  @override
  JsonSchema get inputSchema => {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Name of the observer',
          },
          'outputDir': {
            'type': 'string',
            'description': 'Directory to output the file',
            'default': 'lib/src',
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
    final outputDir = args['outputDir'] ?? 'lib/src';
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      generateObserver: true,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return await plugin.generate(config);
  }
}
