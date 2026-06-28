import '../../../core/plugin_system/capability.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../sync_plugin.dart';

class CreateSyncCapability implements ZuraffaCapability {
  final SyncPlugin plugin;

  CreateSyncCapability(this.plugin);

  @override
  String get name => 'enable';

  @override
  String get description => 'Enable offline-first sync for an entity';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Name of the entity (e.g. Product)',
      },
      'direction': {
        'type': 'string',
        'description': 'Sync direction (push or bidirectional)',
        'default': 'push',
      },
      'batchSize': {
        'type': 'integer',
        'description': 'Number of records per sync batch',
        'default': 50,
      },
      'maxRetries': {
        'type': 'integer',
        'description': 'Maximum sync retry attempts before failing',
        'default': 5,
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
    final direction = args['direction'] ?? 'push';
    final batchSize = args['batchSize'] ?? 50;
    final maxRetries = args['maxRetries'] ?? 5;
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      enableSync: true,
      syncDirection: direction,
      syncBatchSize: batchSize,
      syncMaxRetries: maxRetries,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return await plugin.generate(config);
  }
}
