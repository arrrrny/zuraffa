import '../models/generator_config.dart';
import 'base_plugin_command.dart';
import '../plugins/cache/cache_plugin.dart';

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

    final config = GeneratorConfig(
      name: entityName,
      enableCache: true,
      cachePolicy: policy,
      cacheStorage: storage,
      ttlMinutes: ttl,
      dryRun: isDryRun,
      force: isForce,
      verbose: isVerbose,
      outputDir: outputDir,
    );

    final files = await plugin.generate(config);
    logSummary(files);
  }
}
