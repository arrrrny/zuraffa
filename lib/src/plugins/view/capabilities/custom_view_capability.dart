import '../../../core/plugin_system/capability.dart';
import '../view_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';

class CustomViewCapability implements ZuraffaCapability {
  final ViewPlugin plugin;

  CustomViewCapability(this.plugin);

  @override
  String get name => 'custom';

  @override
  String get description => 'Create a custom Flutter view (non-entity based)';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Name of the view (e.g. Home)',
      },
      'domain': {
        'type': 'string',
        'description': 'Domain folder for the view (e.g. common, auth)',
        'default': 'general',
      },
      'outputDir': {
        'type': 'string',
        'description': 'Directory to output the file',
        'default': 'lib/src',
      },
      'stateless': {
        'type': 'boolean',
        'description': 'Generate a StatelessWidget instead of CleanView',
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
    final domain = args['domain'] ?? 'general';
    final outputDir = args['outputDir'] ?? 'lib/src';
    final stateless = args['stateless'] ?? false;
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    // Create a special config for custom views
    // For custom views, we might not want VPCs unless explicitly specified
    // But for now, let's just make it a simple view
    final config = GeneratorConfig(
      name: name,
      domain: domain,
      outputDir: outputDir,
      generateView: true,
      generateVpcs: false, // Don't generate VPCs for custom view
      generatePresenter: false,
      generateController: false,
      generateState: !stateless, // Use generateState to indicate statefulness for custom view
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return await plugin.generate(config);
  }
}
