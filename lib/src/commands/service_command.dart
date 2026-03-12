import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/service/service_plugin.dart';
import '../plugins/service/capabilities/create_service_capability.dart';

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
  }

  @override
  String get name => 'service';

  @override
  String get description => 'Generate Services';

  @override
  Future<void> run() async {
    final args = argResults?.rest ?? [];
    if (args.isEmpty) {
      print('❌ Usage: zfa service <ServiceName> [options]');
      return;
    }

    final serviceName = args.first;
    final paramsType = (argResults?['params'] as String?) ?? 'NoParams';
    final returnsType = (argResults?['returns'] as String?) ?? 'void';
    final useCaseType = (argResults?['type'] as String?) ?? 'usecase';

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateServiceCapability)
            as CreateServiceCapability;

    final result = await capability.execute({
      'name': serviceName,
      'params': paramsType,
      'returns': returnsType,
      'type': useCaseType,
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
      print('Failed to generate service');
    }
  }
}
