import '../models/generator_config.dart';
import 'base_plugin_command.dart';
import '../plugins/mock/mock_plugin.dart';

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

    final config = GeneratorConfig(
      name: entityName,
      generateMock: !dataOnly,
      generateMockDataOnly: dataOnly,
      dryRun: isDryRun,
      force: isForce,
      verbose: isVerbose,
      outputDir: outputDir,
    );

    final files = await plugin.generate(config);
    logSummary(files);
  }
}
