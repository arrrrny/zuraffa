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
  }

  @override
  String get name => 'mock';

  @override
  String get description => 'Generate Mocks';

  @override
  Future<void> run() async {
    final entityName = argResults!.rest.first;
    final dataOnly = argResults!['data-only'] as bool;

    final capability = plugin.capabilities.firstWhere(
      (c) => c is CreateMockCapability,
    ) as CreateMockCapability;

    final result = await capability.execute({
      'name': entityName,
      'data-only': dataOnly,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    if (result.success) {
      final files = result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
    } else {
      print('Failed to generate mock');
    }
  }
}
