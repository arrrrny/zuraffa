import 'base_plugin_command.dart';
import '../plugins/sqlite/sqlite_plugin.dart';

/// `zfa sqlite [adapter] <Entity>` — generates a SQLite-backed DataSource.
///
/// Both spellings work: the issue's `zfa sqlite adapter Task` and the
/// terser `zfa sqlite Task` (a leading `adapter` positional is skipped).
class SqliteCommand extends PluginCommand {
  @override
  final SqlitePlugin plugin;

  SqliteCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated list of methods '
          '(get,getList,list,create,update,toggle,delete,watch,watchList,initialize)',
      defaultsTo: 'get,getList,create,update,delete',
    );
  }

  @override
  String get name => 'sqlite';

  @override
  String get description =>
      'Generate a SQLite-backed DataSource for an entity (adapter)';

  @override
  Future<void> run() async {
    if (argResults?.command != null) {
      return super.run();
    }

    // Bug #856: the positional grammar this command's usage strings
    // advertised (`zfa sqlite [adapter] <EntityName>`) is unreachable
    // through the CLI — package:args rejects a bare entity name as a
    // subcommand attempt before run() ever executes. The subcommand grammar
    // is the only live contract (`zfa manifest`):
    // `zfa sqlite create --name <Entity>`.
    reportSubcommandUsage();
  }
}
