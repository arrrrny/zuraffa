import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/di/capabilities/create_di_capability.dart';

class ModularDiCommand extends PluginCommand {
  ModularDiCommand(super.plugin) {
    argParser.addOption(
      'domain',
      abbr: 'd',
      help: 'Domain name for the usecase/entity',
    );
    argParser.addOption(
      'service',
      abbr: 's',
      help: 'Service name for custom usecases',
    );
    argParser.addOption(
      'repo',
      abbr: 'r',
      help: 'Repository name for custom usecases',
    );
    argParser.addOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated list of entity methods to wire '
          '(get,create,update,delete,list,watch,getList,watchList). '
          'Defaults to "get,update" for entity-based generation, matching '
          '`zfa usecase create <Entity>`.',
      defaultsTo: 'get,update',
    );
    argParser.addMultiOption(
      'usecases',
      abbr: 'u',
      help: 'List of usecases to orchestrate (e.g. GetUser,GetProfile)',
      splitCommas: true,
    );
    argParser.addFlag(
      'no-entity',
      negatable: false,
      help:
          'Treat as a custom (non-entity) usecase — emit a single '
          '<name>_usecase_di.dart referencing <Name>UseCase '
          '(for hand-written usecases)',
    );
    argParser.addFlag(
      'use-mock',
      negatable: false,
      help: 'Use mock implementation for datasources',
    );
  }

  @override
  String get name => 'di';

  @override
  String get description => 'Generate DI registration for a UseCase or Entity.';

  @override
  Future<void> run() async {
    final args = argResults!.rest;
    if (args.isEmpty) {
      print('❌ Usage: zfa di <Name> [options]');
      return;
    }

    final name = args[0];
    final domain = argResults!['domain'] as String?;
    final service = argResults!['service'] as String?;
    final repo = argResults!['repo'] as String?;
    final useMock = argResults!['use-mock'] == true;
    final noEntity = argResults!['no-entity'] == true;
    final usecases =
        (argResults!['usecases'] as List?)?.cast<String>() ?? const <String>[];

    // #410: mirror UseCaseCommand — `--methods` has a defaultsTo, so blank it
    // to [] when the user did not explicitly pass it OR when this is a custom
    // (non-entity) / orchestrator invocation. CreateDiCapability then applies
    // the canonical ['get','update'] default for the entity-based case.
    var methods =
        (argResults!['methods'] as String?)?.split(',') ??
        const ['get', 'update'];

    final isCustomUseCase =
        repo != null ||
        service != null ||
        usecases.isNotEmpty ||
        noEntity ||
        domain != null;

    if (isCustomUseCase || !(argResults?.wasParsed('methods') ?? false)) {
      methods = const [];
    }

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateDiCapability)
            as CreateDiCapability;

    final result = await capability.execute({
      'name': name,
      'domain': domain,
      'service': service,
      'repo': repo,
      'methods': methods,
      'usecases': usecases,
      'noEntity': noEntity,
      'useMock': useMock,
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
      print('Failed to generate DI');
    }
  }
}
