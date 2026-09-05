import 'base_plugin_command.dart';
import '../plugins/state/state_plugin.dart';
import 'state_create_command.dart';

class StateCommand extends PluginCommand {
  @override
  final StatePlugin plugin;

  StateCommand(this.plugin) : super(plugin) {
    // Issue #976: `create` is a first-party subcommand (verdict
    // envelope + receipt) — declared here so the auto-registration in
    // the super constructor skips it (manualSubcommandNames) and this
    // registration cannot collide (issue #761).
    addSubcommand(StateCreateCommand(plugin));
  }

  /// The `create` subcommand is registered manually above — the
  /// auto-registered generic [CapabilityCommand] would collide and
  /// cannot carry the `--json` verdict flag (its `--json` is the
  /// input-JSON option).
  @override
  Set<String> get manualSubcommandNames => const {'create'};

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
