import '../../core/plugin_system/plugin_interface.dart';
import '../../generator/mock_generator.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';

class MockPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  MockPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  });

  @override
  String get id => 'mock';

  @override
  String get name => 'Mock Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.generateMock && !config.generateMockDataOnly) {
      return [];
    }
    return MockGenerator.generate(
      config,
      outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
  }
}
