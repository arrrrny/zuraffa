import '../models/generator_config.dart';
import 'base_plugin_command.dart';
import '../plugins/state/state_plugin.dart';

class StateCommand extends PluginCommand {
  @override
  final StatePlugin plugin;

  StateCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help: 'Comma-separated list of methods (get,create,update,delete,list)',
      defaultsTo: 'get,list,create,update,delete',
    );
  }

  @override
  String get name => 'state';

  @override
  String get description => 'Generate State classes';

  @override
  Future<void> run() async {
    final entityName = argResults!.rest.first;
    final methods = (argResults!['methods'] as String).split(',');

    final config = GeneratorConfig(
      name: entityName,
      methods: methods,
      generateState: true,
      dryRun: isDryRun,
      force: isForce,
      verbose: isVerbose,
      outputDir: outputDir,
    );

    final files = await plugin.generate(config);
    logSummary(files);
  }
}
