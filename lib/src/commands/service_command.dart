import 'base_plugin_command.dart';
import '../plugins/service/service_plugin.dart';
import 'service_create_command.dart';
import 'service_verify_command.dart';

class ServiceCommand extends PluginCommand {
  @override
  final ServicePlugin plugin;

  ServiceCommand(this.plugin) : super(plugin) {
    // SPEC 917 / #876 sweep: the parent-level generator flags
    // (--params/--returns/--type/--init) were parsed and advertised but
    // NEVER read — run() is dispatch-only (the live surface is
    // `zfa service create ...`). Silent parent options are the #876
    // "flags that lie" family; they are gone and `zfa manifest --verify`
    // certifies the parent surface (spec #979).

    // SPEC 1127 (issue #1127): `create` and `verify` are first-party
    // subcommands — `create` upgrades `--json` to the canonical
    // canonical verdict envelope (issue #1105), adds `--explain`, and
    // proves receipts + conformance; `verify` is the grammar gate.
    // Declared here so the auto-registration in the super constructor
    // skips them (manualSubcommandNames) and the registration cannot
    // collide (issue #761).
    addSubcommand(ServiceCreateCommand(plugin));
    addSubcommand(ServiceVerifyCommand(plugin));
  }

  /// `create` and `verify` are registered manually above — the
  /// auto-registered generic [CapabilityCommand] for `create` cannot
  /// carry the machine surface (its `--json` is the input-JSON option,
  /// not the output-envelope flag), and the generic runner has no
  /// `verify` verb at all.
  @override
  Set<String> get manualSubcommandNames => const {'create', 'verify'};

  @override
  String get name => 'service';

  @override
  String get description => 'Generate Services';

  @override
  Future<void> run() async {
    // Bug #856: the positional grammar this command's usage strings
    // advertised (`zfa service <ServiceName>`) is unreachable through the
    // CLI — package:args rejects a bare service name as a subcommand attempt
    // before run() ever executes. The subcommand grammar is the only live
    // contract (`zfa manifest`): `zfa service create --name <Service>`.
    reportSubcommandUsage();
  }
}
