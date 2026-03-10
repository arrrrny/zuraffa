import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/usecase/usecase_plugin.dart';
import '../plugins/usecase/capabilities/create_usecase_capability.dart';

class UseCaseCommand extends PluginCommand {
  @override
  final UseCasePlugin plugin;

  UseCaseCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help: 'Comma-separated list of methods (get,create,update,delete,list)',
      defaultsTo: 'get,list,create,update,delete',
    );
    argParser.addOption(
      'type',
      abbr: 't',
      allowed: ['future', 'stream', 'completable', 'sync', 'background'],
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
  }

  @override
  String get name => 'usecase';

  @override
  String get description => 'Generate UseCases';

  @override
  Future<void> run() async {
    final entityName = argResults!.rest.first;
    var methods = (argResults!['methods'] as String).split(',');
    final type = argResults!['type'] as String;
    final usecases = (argResults!['usecases'] as List?)?.cast<String>() ?? [];

    final domain = argResults!['domain'] as String?;
    final repo = argResults!['repo'] as String?;
    final service = argResults!['service'] as String?;
    final params = argResults!['params'] as String?;
    final returns = argResults!['returns'] as String?;

    final isCustomUseCase = repo != null ||
        service != null ||
        usecases.isNotEmpty ||
        (params != null && returns != null);

    if (isCustomUseCase || !argResults!.wasParsed('methods')) {
      methods = [];
    }

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateUseCaseCapability)
            as CreateUseCaseCapability;

    final result = await capability.execute({
      'name': entityName,
      'methods': methods,
      'type': type,
      'usecases': usecases,
      'domain': domain,
      'repo': repo,
      'service': service,
      'params': params,
      'returns': returns,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'revert': isRevert,
      'outputDir': outputDir,
    });

    if (result.success) {
      final files =
          result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
    } else {
      print('Failed to generate usecase');
    }
  }
}
