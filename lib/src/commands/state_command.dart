import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/state/state_plugin.dart';
import '../plugins/state/capabilities/create_state_capability.dart';

class StateCommand extends PluginCommand {
  @override
  final StatePlugin plugin;

  StateCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help: 'Comma-separated list of methods (get,create,update,delete,list,watch,getList,watchList)',
      defaultsTo: 'get,update',
    );
  }

  @override
  String get name => 'state';

  @override
  String get description => 'Generate State classes';

  @override
  Future<void> run() async {
    if (argResults?.rest.isEmpty ?? true) {
      print('❌ Usage: zfa state <EntityName> [options]');
      return;
    }

    final entityName = argResults!.rest.first;
    final methods = (argResults?['methods'] as String?)?.split(',') ??
        ['get', 'update'];

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateStateCapability)
            as CreateStateCapability;

    final result = await capability.execute({
      'name': entityName,
      'methods': methods,
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
      print('Failed to generate state');
    }
  }
}
