import 'base_plugin_command.dart';
import '../plugins/state/state_plugin.dart';

class StateCommand extends PluginCommand {
  @override
  final StatePlugin plugin;

  StateCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated list of methods (get,create,update,delete,list,watch,getList,watchList)',
      defaultsTo: 'get,update',
    );
  }

  @override
  String get name => 'state';

  @override
  String get description => 'Generate State classes';

  @override
  Future<void> run() async {
    // Bug #856: the positional grammar this command's usage strings
    // advertised (`zfa state <EntityName>`) is unreachable through the
    // CLI — package:args rejects a bare entity name as a subcommand attempt
    // before run() ever executes. The subcommand grammar is the only live
    // contract (`zfa manifest`): `zfa state create --name <Entity>`.
    reportSubcommandUsage();
  }
}
