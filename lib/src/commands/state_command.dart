import 'base_plugin_command.dart';
import '../plugins/state/state_plugin.dart';
import 'state_create_command.dart';
import 'state_verify_command.dart';

class StateCommand extends PluginCommand {
  @override
  final StatePlugin plugin;

  StateCommand(this.plugin) : super(plugin) {
    // Issue #976: `create` is a first-party subcommand (verdict
    // envelope + receipt) — declared here so the auto-registration in
    // the super constructor skips it (manualSubcommandNames) and this
    // registration cannot collide (issue #761).
    //
    // SPEC 1126: `verify` joins as the second first-party subcommand —
    // the receipt-contract drift gate (`zfa state verify <Entity>`),
    // the grammar gate every A+ plugin ships (cache/provider/service/
    // datasource precedents).
    addSubcommand(StateCreateCommand(plugin));
    addSubcommand(StateVerifyCommand(plugin));
  }

  /// `create` and `verify` are registered manually above — the
  /// auto-registered generic [CapabilityCommand] for `create` cannot
  /// carry the `--json` verdict flag (its `--json` is the input-JSON
  /// option), and the generic runner has no `verify` verb at all.
  @override
  Set<String> get manualSubcommandNames => const {'create', 'verify'};

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
