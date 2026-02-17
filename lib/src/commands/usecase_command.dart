import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/usecase/usecase_plugin.dart';
import '../plugins/usecase/capabilities/create_usecase_capability.dart';

class UseCaseCommand extends PluginCommand {
  @override
  final UseCasePlugin plugin;

  UseCaseCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help: 'Comma-separated list of methods (get,create,update,delete,list)',
      defaultsTo: 'get,list,create,update,delete',
    );
    argParser.addOption(
      'type',
      abbr: 't',
      allowed: ['entity', 'custom', 'stream'],
      defaultsTo: 'entity',
      help: 'Type of usecase to generate',
    );
  }

  @override
  String get name => 'usecase';

  @override
  String get description => 'Generate UseCases';

  @override
  Future<void> run() async {
    final entityName = argResults!.rest.first;
    final methods = (argResults!['methods'] as String).split(',');
    final type = argResults!['type'] as String;

    final capability = plugin.capabilities.firstWhere(
      (c) => c is CreateUseCaseCapability,
    ) as CreateUseCaseCapability;

    final result = await capability.execute({
      'name': entityName,
      'methods': methods,
      'type': type,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    if (result.success) {
      final files = result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
    } else {
      print('Failed to generate usecase');
    }
  }
}
