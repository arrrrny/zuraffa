import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/provider/provider_plugin.dart';
import '../plugins/provider/capabilities/create_provider_capability.dart';

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
  }

  @override
  String get name => 'provider';

  @override
  String get description => 'Generate Providers';

  @override
  Future<void> run() async {
    if (argResults?.rest.isEmpty ?? true) {
      print('❌ Usage: zfa provider <EntityName> [options]');
      return;
    }

    final entityName = argResults!.rest.first;
    final generateData = argResults?['data'] as bool? ?? true;
    final domain = argResults?['domain'];
    final params = argResults?['params'];
    final returns = argResults?['returns'];
    final type = argResults?['type'];

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateProviderCapability)
            as CreateProviderCapability;

    final result = await capability.execute({
      'name': entityName,
      'data': generateData,
      'domain': domain,
      'params': params,
      'returns': returns,
      'type': type,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    if (result.success) {
      final files =
          result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
    } else {
      // Handle error
      print('Failed to generate provider');
    }
  }
}
