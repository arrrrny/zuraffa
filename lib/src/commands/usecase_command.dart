import 'base_plugin_command.dart';
import '../plugins/usecase/usecase_plugin.dart';
import 'usecase_create_command.dart';

class UseCaseCommand extends PluginCommand {
  @override
  final UseCasePlugin plugin;

  UseCaseCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated list of methods (get,create,update,delete,list,watch,getList,watchList)',
      defaultsTo: 'get,update',
    );
    argParser.addOption(
      'type',
      abbr: 't',
      allowed: [
        'future',
        'stream',
        'completable',
        'sync',
        'background',
        'os_background',
      ],
      defaultsTo: 'future',
      help: 'Execution strategy (default: future/fetch)',
    );
    argParser.addMultiOption(
      'usecases',
      abbr: 'u',
      help: 'List of usecases to orchestrate (e.g. GetUser,GetProfile)',
      splitCommas: true,
    );
    argParser.addOption(
      'domain',
      help: 'Domain name (required for non-entity usecases)',
    );
    argParser.addOption(
      'repo',
      help: 'Repository class to inject (e.g. UserRepository)',
    );
    argParser.addOption(
      'service',
      help: 'Service class to inject (e.g. AuthService)',
    );
    argParser.addOption(
      'params',
      help: 'Parameter type (e.g. String, UserParams)',
    );
    argParser.addOption(
      'returns',
      help: 'Return type (e.g. void, User, List<User>)',
    );

    // Spec #972 FR-2: the rich first-party `create` subcommand registers
    // itself (per-method --json verdicts, receipts, exit codes). Listed in
    // [manualSubcommandNames] so the auto-registration below skips the
    // capability-derived duplicate (issue #761: a duplicate addSubcommand
    // would leave one of them unparented and crash --help).
    addSubcommand(UseCaseCreateCommand(plugin));
  }

  @override
  Set<String> get manualSubcommandNames => const {'create'};

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
