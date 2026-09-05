import 'base_plugin_command.dart';
import '../plugins/provider/provider_plugin.dart';
import 'provider_verify_command.dart';

class ProviderCommand extends PluginCommand {
  @override
  final ProviderPlugin plugin;

  // Spec #979 (order 3) — the dead parent-flag purge.
  //
  // ProviderCommand used to register six plugin-specific parent-level
  // flags — `--domain`, `--params`, `--returns`, `--type`, `--data`,
  // `--init` — but bug #856 proved this command's run() is unreachable
  // through the CLI dispatch (package:args rejects a bare entity name as
  // a subcommand attempt before run() ever executes), so no flag value
  // parsed at this level could ever reach the generator. `--help`
  // advertised them (issue #876: "flags that lie about what they
  // control"), users passed them, and the subcommand's own schema-derived
  // values silently won. All six registrations are DELETED; the live
  // grammar keeps every knob on `zfa provider create`, where
  // CapabilityCommand synthesizes the flags from the create capability's
  // inputSchema (which now also carries `init` and the `type` enum —
  // schema ≡ grammar). Grep-proof: this file registers nothing beyond
  // [PluginCommand]'s standard machinery. `zfa manifest --verify
  // provider` certifies the surface green.
  //
  // Spec #979 (orders 2 + 4): `verify` is a manual subcommand — the
  // stub-escape + conformance gate (`zfa provider verify <Entity>`).
  ProviderCommand(this.plugin, {String? projectRoot}) : super(plugin) {
    addSubcommand(ProviderVerifyCommand(projectRoot: projectRoot));
  }

  @override
  Set<String> get manualSubcommandNames => const {'verify'};

  @override
  String get name => 'provider';

  @override
  String get description => 'Generate Providers';

  @override
  Future<void> run() async {
    if (argResults?.command != null) {
      return super.run();
    }

    // Bug #856: the positional grammar this command's usage strings
    // advertised (`zfa provider <EntityName>`) is unreachable through the
    // CLI — package:args rejects a bare entity name as a subcommand attempt
    // before run() ever executes. The subcommand grammar is the only live
    // contract (`zfa manifest`): `zfa provider create --name <Entity>`,
    // `zfa provider verify <Entity>`.
    reportSubcommandUsage();
  }
}
