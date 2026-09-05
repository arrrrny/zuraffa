import 'base_plugin_command.dart';
import '../plugins/route/route_plugin.dart';
import 'route_create_command.dart';
import 'route_verify_command.dart';

class RouteCommand extends PluginCommand {
  @override
  final RoutePlugin plugin;

  // Issue #971 order 1: the `--methods` option that used to be registered
  // here was DEAD — bug #856 proved this command's run() is unreachable
  // through the CLI dispatch (package:args rejects a bare entity name as a
  // subcommand attempt before run() ever executes), so no flag value parsed
  // at this level could ever reach the generator. Meanwhile `--help`
  // advertised it, misleading readers into `zfa route --methods get Product`
  // — a shape the dispatcher rejects. Deleted; the live grammar keeps the
  // flag on `zfa route create`, where the create capability actually
  // consumes it. Bare `zfa route` still exits 64 via
  // [PluginCommand.reportSubcommandUsage].
  //
  // Issue #971 orders 2-5: `create` is now a MANUAL subcommand
  // (RouteCreateCommand) so `--json` can be the machine verdict envelope
  // output flag instead of the generic input-args JSON option the
  // schema-generated CapabilityCommand registers.
  RouteCommand(this.plugin, {String? projectRoot}) : super(plugin) {
    addSubcommand(RouteCreateCommand(plugin, projectRoot: projectRoot));
    addSubcommand(RouteVerifyCommand(projectRoot: projectRoot));
  }

  @override
  Set<String> get manualSubcommandNames => const {'create', 'verify'};

  @override
  String get name => 'route';

  @override
  String get description => 'Generate route definitions for an entity';

  @override
  Future<void> run() async {
    // Bug #856: the positional grammar this command's usage strings
    // advertised (`zfa route <EntityName>`) is unreachable through the
    // CLI — package:args rejects a bare entity name as a subcommand attempt
    // before run() ever executes. The subcommand grammar is the only live
    // contract (`zfa manifest`): `zfa route create|custom|deep-link|shell`.
    reportSubcommandUsage();
  }
}
