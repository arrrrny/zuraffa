import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/mock/mock_plugin.dart';
import '../plugins/mock/capabilities/create_mock_capability.dart';

class MockCommand extends PluginCommand {
  @override
  final MockPlugin plugin;

  MockCommand(this.plugin) : super(plugin) {
    argParser.addFlag(
      'data-only',
      help: 'Generate only mock data (fixtures)',
      defaultsTo: false,
    );
    argParser.addOption('service', help: 'Service name for mock provider');
    argParser.addOption('domain', help: 'Domain folder for the mock provider');
    argParser.addOption('params', help: 'Parameter type for mock methods');
    argParser.addOption('returns', help: 'Return type for mock methods');
  }

  @override
  String get name => 'mock';

  @override
  String get description => 'Generate Mocks';

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      print('❌ Error: Entity name is required.');
      print('Usage: zfa mock <EntityName> [options]');
      return;
    }
    final entityName = argResults!.rest.first;
    final dataOnly = argResults!['data-only'] as bool;
    final service = argResults!['service'] as String?;
    final domain = argResults!['domain'] as String?;
    final params = argResults!['params'] as String?;
    final returns = argResults!['returns'] as String?;

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateMockCapability)
            as CreateMockCapability;

    final result = await capability.execute({
      'name': entityName,
      'data-only': dataOnly,
      'service': service,
      'domain': domain,
      'params': params,
      'returns': returns,
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
      print('Failed to generate mock');
    }
  }
}
