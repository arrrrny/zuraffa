import 'base_plugin_command.dart';
import '../plugins/route/route_plugin.dart';

class RouteCommand extends PluginCommand {
  @override
  final RoutePlugin plugin;

  RouteCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated list of methods (get,create,update,delete,list,watch,getList,watchList)',
      defaultsTo: 'get,update',
    );
  }

  @override
  String get name => 'route';

  @override
  String get description => 'Generate route definitions for an entity';

  @override
  Future<void> run() async {
    // Bug #856: the positional grammar this command's usage strings
    // advertised (`zfa route <EntityName>`) is unreachable through the
    // CLI — package:args rejects a bare entity name as a subcommand attempt
    // before run() ever executes. The subcommand grammar is the only live
    // contract (`zfa manifest`): `zfa route create|custom|deep-link|shell`.
    reportSubcommandUsage();
  }
}
