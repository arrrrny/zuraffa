import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/sync/sync_plugin.dart';
import '../plugins/sync/capabilities/create_sync_capability.dart';

class SyncCommand extends PluginCommand {
  @override
  final SyncPlugin plugin;

  SyncCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'direction',
      help: 'Sync direction (push or bidirectional)',
      defaultsTo: 'push',
      allowed: ['push', 'bidirectional'],
    );
    argParser.addOption(
      'batch-size',
      help: 'Number of records per sync batch',
      defaultsTo: '50',
    );
    argParser.addOption(
      'max-retries',
      help: 'Maximum sync retry attempts before failing',
      defaultsTo: '5',
    );
  }

  @override
  String get name => 'sync';

  @override
  String get description => 'Generate offline-first sync logic';

  @override
  Future<void> run() async {
    final entityName = argResults!.rest.first;
    final direction = argResults!['direction'] as String;
    final batchSizeStr = argResults!['batch-size'] as String;
    final maxRetriesStr = argResults!['max-retries'] as String;
    final batchSize = int.tryParse(batchSizeStr) ?? 50;
    final maxRetries = int.tryParse(maxRetriesStr) ?? 5;

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateSyncCapability)
            as CreateSyncCapability;

    final result = await capability.execute({
      'name': entityName,
      'direction': direction,
      'batchSize': batchSize,
      'maxRetries': maxRetries,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    if (result.success) {
      final files =
          result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
    } else {
      print('Failed to generate sync');
    }
  }
}
