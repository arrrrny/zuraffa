import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/observer/observer_plugin.dart';
import '../plugins/observer/capabilities/create_observer_capability.dart';

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

    final capability = plugin.capabilities.firstWhere(
      (c) => c is CreateObserverCapability,
    ) as CreateObserverCapability;

    final result = await capability.execute({
      'name': entityName,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    if (result.success) {
      final files = result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
    } else {
      print('Failed to generate observer');
    }
  }
}
