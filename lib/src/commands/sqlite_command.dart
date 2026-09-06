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
    // SPEC 917 / #876 sweep: the parent-level --methods was parsed and
    // advertised but NEVER read — run() is dispatch-only (the live surface
    // is `zfa sqlite create --name <Entity> --methods ...` from the
    // capability schema). Silent parent options are the #876 "flags that
    // lie" family; `zfa manifest --verify` certifies the surface.
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
