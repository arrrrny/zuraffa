import '../models/generator_config.dart';
import 'base_plugin_command.dart';
import '../plugins/provider/provider_plugin.dart';

class ProviderCommand extends PluginCommand {
  @override
  final ProviderPlugin plugin;

  ProviderCommand(this.plugin) : super(plugin) {
    argParser.addFlag(
      'data',
      help: 'Generate data layer dependencies',
      defaultsTo: true,
    );
  }

  @override
  String get name => 'provider';

  @override
  String get description => 'Generate Providers';

  @override
  Future<void> run() async {
    final entityName = argResults!.rest.first;
    final generateData = argResults!['data'] as bool;

    final config = GeneratorConfig(
      name: entityName,
      // ProviderPlugin requires hasService and generateData to be true?
      // "if (!config.hasService || !config.generateData)"
      // GeneratorConfig.hasService returns true if service != null || generateVpc (via defaults).
      // Let's ensure service is not null, or we assume it generates a provider for a service.
      // Usually provider wraps a service.
      service:
          entityName, // Assume service name matches entity name for standalone
      generateData: generateData,
      dryRun: isDryRun,
      force: isForce,
      verbose: isVerbose,
      outputDir: outputDir,
    );

    final files = await plugin.generate(config);
    logSummary(files);
  }
}
