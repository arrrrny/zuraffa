import '../../../core/plugin_system/capability.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../module_plugin.dart';

/// Capability that creates the feature plugin orchestrator file.
class CreateModuleCapability implements ZuraffaCapability {
  final ModuleGeneratorPlugin plugin;

  CreateModuleCapability(this.plugin);

  @override
  String get name => 'create_module';

  @override
  String get description =>
      'Generate a ZuraffaPlugin orchestrator for a feature package';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': 'Name of the feature'},
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
    );
  }

  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final config = GeneratorConfig(
      name: args['name'],
      outputDir: plugin.outputDir,
      dryRun: dryRun,
      force: args['force'] ?? false,
      verbose: args['verbose'] ?? false,
    );
    return plugin.generate(config);
  }
}
