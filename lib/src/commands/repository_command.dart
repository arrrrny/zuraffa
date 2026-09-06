import 'base_plugin_command.dart';
import '../plugins/repository/repository_plugin.dart';
import 'repository_create_command.dart';

class RepositoryCommand extends PluginCommand {
  @override
  final RepositoryPlugin plugin;

  RepositoryCommand(this.plugin) : super(plugin) {
    // SPEC 1124 (issue #1124): `create` is a first-party subcommand —
    // [RepositoryCreateCommand] carries the canonical `zuraffa.verdict.v1`
    // `--json` envelope. Declared here so the auto-registration in the
    // super constructor skips it (manualSubcommandNames) and this
    // registration cannot collide (issue #761).
    addSubcommand(RepositoryCreateCommand(plugin));
  }

  /// The `create` subcommand is registered manually above — the
  /// auto-registered generic [CapabilityCommand] would collide and
  /// cannot carry the `--json` verdict flag (its `--json` is the
  /// input-JSON option).
  @override
  Set<String> get manualSubcommandNames => const {'create'};

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
