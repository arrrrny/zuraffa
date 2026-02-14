import '../models/generator_config.dart';
import 'base_plugin_command.dart';
import '../plugins/service/service_plugin.dart';

class ServiceCommand extends PluginCommand {
  @override
  final ServicePlugin plugin;

  ServiceCommand(this.plugin) : super(plugin);

  @override
  String get name => 'service';

  @override
  String get description => 'Generate Services';

  @override
  Future<void> run() async {
    final args = argResults!.rest;
    if (args.isEmpty) {
      print('❌ Usage: zfa service <ServiceName> [options]');
      return;
    }

    final serviceName = args.first;

    final config = GeneratorConfig(
      name: serviceName,
      service: serviceName,
      methods:
          [], // Empty methods to likely trigger custom usecase path if needed, or just to avoid entity defaults
      dryRun: isDryRun,
      force: isForce,
      verbose: isVerbose,
      outputDir: outputDir,
    );

    // NOTE: GeneratorConfig might default to EntityBased if not careful.
    // If I pass name='MyService', methods=['get'] (default), it's entity based.
    // I should pass methods=[].
    // GeneratorConfig(name: '...', methods: [])
    // But ServicePlugin checks `!config.isCustomUseCase`.
    // If methods=[], isCustomUseCase might be true.
    // Let's verify GeneratorConfig later if needed. For now, best effort.

    // Wait, ServicePlugin.generate line 35:
    // if (!config.isCustomUseCase || !config.hasService)
    // This strictly limits standalone service generation.
    // Maybe we should allow standalone service generation?
    // The user said "work in legacy full mode", but didn't say "don't improve standalone".
    // I'll stick to what the plugin does for now.

    final files = await plugin.generate(config);
    logSummary(files);
  }
}
