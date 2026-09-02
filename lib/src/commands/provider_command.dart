import 'base_plugin_command.dart';
import '../plugins/provider/provider_plugin.dart';

class ProviderCommand extends PluginCommand {
  @override
  final ProviderPlugin plugin;

  ProviderCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'domain',
      abbr: 'd',
      help: 'Domain folder for the provider',
    );
    argParser.addOption(
      'params',
      abbr: 'p',
      help: 'Parameter type for the provider method',
      defaultsTo: 'NoParams',
    );
    argParser.addOption(
      'returns',
      abbr: 'r',
      help: 'Return type for the provider method',
      defaultsTo: 'void',
    );
    argParser.addOption(
      'type',
      abbr: 't',
      help: 'Provider method type (sync, stream, completable)',
      allowed: ['sync', 'stream', 'completable', 'usecase'],
      defaultsTo: 'usecase',
    );
    argParser.addFlag(
      'data',
      help: 'Generate data layer dependencies',
      defaultsTo: true,
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
    // contract (`zfa manifest`): `zfa provider create --name <Entity>`.
    reportSubcommandUsage();
  }
}
