import 'base_plugin_command.dart';
import '../plugins/service/service_plugin.dart';

class ServiceCommand extends PluginCommand {
  @override
  final ServicePlugin plugin;

  ServiceCommand(this.plugin) : super(plugin) {
    // SPEC 917 / #876 sweep: the parent-level generator flags
    // (--params/--returns/--type/--init) were parsed and advertised but
    // NEVER read — run() is dispatch-only (the live surface is
    // `zfa service create ...` from the capability schema). Silent parent
    // options are the #876 "flags that lie" family; they are gone and
    // `zfa manifest --verify` certifies the parent surface (spec #979).
  }

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
