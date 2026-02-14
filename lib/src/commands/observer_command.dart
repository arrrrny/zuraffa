import '../models/generator_config.dart';
import 'base_plugin_command.dart';
import '../plugins/observer/observer_plugin.dart';

class ObserverCommand extends PluginCommand {
  @override
  final ObserverPlugin plugin;

  ObserverCommand(this.plugin) : super(plugin);

  @override
  String get name => 'observer';

  @override
  String get description => 'Generate Observer';

  @override
  Future<void> run() async {
    final entityName = argResults!.rest.first;

    final config = GeneratorConfig(
      name: entityName,
      generateObserver: true,
      dryRun: isDryRun,
      force: isForce,
      verbose: isVerbose,
      outputDir: outputDir,
    );

    final files = await plugin.generate(config);
    logSummary(files);
  }
}
