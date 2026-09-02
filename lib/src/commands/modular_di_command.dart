import 'base_plugin_command.dart';

class ModularDiCommand extends PluginCommand {
  ModularDiCommand(super.plugin) {
    argParser.addOption(
      'domain',
      abbr: 'd',
      help: 'Domain name for the usecase/entity',
    );
    argParser.addOption(
      'service',
      abbr: 's',
      help: 'Service name for custom usecases',
    );
    argParser.addOption(
      'repo',
      abbr: 'r',
      help: 'Repository name for custom usecases',
    );
    argParser.addOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated list of entity methods to wire '
          '(get,create,update,delete,list,watch,getList,watchList). '
          'Defaults to "get,update" for entity-based generation, matching '
          '`zfa usecase create <Entity>`.',
      defaultsTo: 'get,update',
    );
    argParser.addMultiOption(
      'usecases',
      abbr: 'u',
      help: 'List of usecases to orchestrate (e.g. GetUser,GetProfile)',
      splitCommas: true,
    );
    argParser.addFlag(
      'no-entity',
      negatable: false,
      help:
          'Treat as a custom (non-entity) usecase — emit a single '
          '<name>_usecase_di.dart referencing <Name>UseCase '
          '(for hand-written usecases)',
    );
    argParser.addFlag(
      'use-mock',
      negatable: false,
      help: 'Use mock implementation for datasources',
    );
  }

  @override
  String get name => 'di';

  @override
  String get description => 'Generate DI registration for a UseCase or Entity.';

  @override
  Future<void> run() async {
    // Bug #856: the positional grammar this command's usage strings
    // advertised (`zfa di <Name>`) is unreachable through the CLI —
    // package:args rejects a bare name as a subcommand attempt before run()
    // ever executes. The subcommand grammar is the only live contract
    // (`zfa manifest`): `zfa di create|register`.
    reportSubcommandUsage();
  }
}
