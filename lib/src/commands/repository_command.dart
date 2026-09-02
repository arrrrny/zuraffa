import 'base_plugin_command.dart';
import '../plugins/repository/repository_plugin.dart';

class RepositoryCommand extends PluginCommand {
  @override
  final RepositoryPlugin plugin;

  RepositoryCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated list of methods (get,create,update,delete,list,watch,getList,watchList)',
      defaultsTo: 'get,update',
    );
    argParser.addFlag(
      'data',
      help: 'Generate repository implementation',
      defaultsTo: true,
    );
    argParser.addFlag(
      'datasource',
      help: 'Generate data sources along with repository',
      defaultsTo: true,
    );
    argParser.addFlag(
      'init',
      abbr: 'i',
      help: 'Generate initialization and disposal methods',
      defaultsTo: false,
      negatable: false,
    );
  }

  @override
  String get name => 'repository';

  @override
  String get description => 'Generate Repositories';

  @override
  Future<void> run() async {
    // Bug #856: the positional grammar this command's usage strings
    // advertised (`zfa repository <EntityName>`) is unreachable through the
    // CLI — package:args rejects a bare entity name as a subcommand attempt
    // before run() ever executes. The subcommand grammar is the only live
    // contract (`zfa manifest`): `zfa repository create --name <Entity>`.
    reportSubcommandUsage();
  }
}
