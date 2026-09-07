import 'base_plugin_command.dart';
import '../plugins/usecase/usecase_plugin.dart';
import 'usecase_create_command.dart';
import 'usecase_verify_command.dart';

class UseCaseCommand extends PluginCommand {
  @override
  final UseCasePlugin plugin;

  UseCaseCommand(this.plugin) : super(plugin) {
    // SPEC 917 / #876 sweep: the parent-level generator flags
    // (--methods/--type/--usecases/--domain/--repo/--service/--params/
    // --returns) were parsed and advertised but NEVER read — run() is
    // dispatch-only (the live surface is `zfa usecase create ...`, whose
    // parser owns its flags). Silent parent options are the #876 "flags
    // that lie" family; they are gone and `zfa manifest --verify`
    // certifies the parent surface (spec #979).

    // Spec #972 FR-2: the rich first-party `create` subcommand registers
    // itself (per-method --json verdicts, receipts, exit codes). Listed in
    // [manualSubcommandNames] so the auto-registration below skips the
    // capability-derived duplicate (issue #761: a duplicate addSubcommand
    // would leave one of them unparented and crash --help).
    // SPEC 1119: the first-party `verify` gate registers itself the same
    // way (per-method conformance + entity drift, exit 1 with fix lines).
    addSubcommand(UseCaseCreateCommand(plugin));
    addSubcommand(UseCaseVerifyCommand(plugin));
  }

  @override
  Set<String> get manualSubcommandNames => const {'create', 'verify'};

  @override
  String get name => 'usecase';

  @override
  String get description => 'Generate UseCases';

  @override
  Future<void> run() async {
    // Spec #972 FR-1 (mirrors bug #856 / repository_command.dart): the
    // positional grammar this command's usage strings advertised
    // (`zfa usecase <EntityName>`) is unreachable through the CLI —
    // package:args rejects a bare entity name as a subcommand attempt
    // before run() ever executes. run() is only reachable through direct
    // (programmatic) invocation; it must tell the truth about the
    // grammar, never generate, and exit non-zero (64) instead of
    // silently no-op'ing with exit code 0.
    reportSubcommandUsage();
  }
}
