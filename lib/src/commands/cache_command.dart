import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/cache/cache_plugin.dart';
import '../plugins/cache/capabilities/create_cache_capability.dart';

class CacheCommand extends PluginCommand {
  @override
  final CachePlugin plugin;

  CacheCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'policy',
      help: 'Cache policy (daily, hourly, etc.)',
      defaultsTo: 'daily',
    );
    argParser.addOption('storage', help: 'Storage backend (hive, etc.)');
    argParser.addOption('ttl', help: 'Time to live in minutes');
  }

  @override
  String get name => 'cache';

  @override
  String get description => 'Generate Cache logic';

  @override
  Future<void> run() async {
    final entityName = argResults!.rest.first;
    final policy = argResults!['policy'] as String;
    final storage = argResults!['storage'] as String?;
    final ttlStr = argResults!['ttl'] as String?;
    final ttl = ttlStr != null ? int.tryParse(ttlStr) : null;

    final capability = plugin.capabilities.firstWhere(
      (c) => c is CreateCacheCapability,
    ) as CreateCacheCapability;

    final result = await capability.execute({
      'name': entityName,
      'policy': policy,
      'storage': storage,
      'ttl': ttl,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    if (result.success) {
      final files = result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
    } else {
      print('Failed to generate cache');
    }
  }
}
