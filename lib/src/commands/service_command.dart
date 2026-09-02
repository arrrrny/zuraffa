import 'base_plugin_command.dart';
import '../plugins/service/service_plugin.dart';

class ServiceCommand extends PluginCommand {
  @override
  final ServicePlugin plugin;

  ServiceCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'params',
      abbr: 'p',
      help: 'Parameter type for the service method (e.g. String, MyParams)',
      defaultsTo: 'NoParams',
    );
    argParser.addOption(
      'returns',
      abbr: 'r',
      help: 'Return type for the service method (e.g. String, List<int>)',
      defaultsTo: 'void',
    );
    argParser.addOption(
      'type',
      abbr: 't',
      help: 'Service method type (sync, stream, completable)',
      allowed: ['sync', 'stream', 'completable', 'usecase'],
      defaultsTo: 'usecase',
    );
    argParser.addFlag(
      'init',
      abbr: 'i',
      help: 'Generate initialization and disposal methods',
      defaultsTo: false,
      negatable: false,
    );
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
