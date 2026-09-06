import 'base_plugin_command.dart';
import '../plugins/repository/repository_plugin.dart';

class RepositoryCommand extends PluginCommand {
  @override
  final RepositoryPlugin plugin;

  RepositoryCommand(this.plugin) : super(plugin) {
    // SPEC 917 / #876 sweep: the parent-level generator flags
    // (--methods/--data/--datasource/--init) were parsed and advertised but
    // NEVER read — run() is dispatch-only (the live surface is
    // `zfa repository create ...` from the capability schema). Silent
    // parent options are the #876 "flags that lie" family; they are gone
    // and `zfa manifest --verify` certifies the parent surface (spec #979).
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
