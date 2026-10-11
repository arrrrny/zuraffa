import 'dart:io';
import '../core/plugin_system/capability_invocation_wrapper.dart';
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

  /// SPEC 917 / #876 sweep: run()'s programmatic positional path reads
  /// every parent-level flag listed below — they are LIVE, declared here so
  /// `zfa manifest --verify` certifies them instead of flagging them dead
  /// (spec #979).
  @override
  Set<String> get consumedParentFlags => const {
    'batch-size',
    'direction',
    'max-retries',
  };

  @override
  Future<void> run() async {
    if (argResults?.rest.isEmpty ?? true) {
      reportSubcommandUsage();
      return;
    }
    final entityName = argResults!.rest.first;
    final direction = argResults!['direction'] as String;
    final batchSizeStr = argResults!['batch-size'] as String;
    final maxRetriesStr = argResults!['max-retries'] as String;
    final batchSize = int.tryParse(batchSizeStr) ?? 50;
    final maxRetries = int.tryParse(maxRetriesStr) ?? 5;

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateSyncCapability)
            as CreateSyncCapability;

    // Issue #1138: route the standalone invocation through the
    // CapabilityInvocationWrapper so a successful run persists its
    // proof.v1 receipt (best-effort inside the wrapper).
    final wrapper = CapabilityInvocationWrapper(
      capability: capability,
      pluginId: plugin.id,
    );
    final result = await wrapper.execute({
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
      // Bug #1139 (exit-code sweep, #856 pattern): a failed generation is a
      // failure — the process must never exit 0 after printing an error.
      print('❌ Failed to generate sync: ${result.message ?? "unknown error"}');
      exitCode = 1;
    }
  }
}
