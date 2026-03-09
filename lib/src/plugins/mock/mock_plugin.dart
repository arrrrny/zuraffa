import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import '../../commands/mock_command.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/capability.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/string_utils.dart';
import 'builders/mock_builder.dart';
import 'capabilities/create_mock_capability.dart';

class MockPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  late final MockBuilder mockBuilder;

  MockPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  }) {
    mockBuilder = MockBuilder(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
  }

  @override
  List<ZuraffaCapability> get capabilities => [
        CreateMockCapability(this),
      ];

  @override
  Command createCommand() => MockCommand(this);

  @override
  String get id => 'mock';

  @override
  String get name => 'Mock Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (config.outputDir != outputDir ||
        config.dryRun != dryRun ||
        config.force != force ||
        config.verbose != verbose) {
      final delegator = MockPlugin(
        outputDir: config.outputDir,
        dryRun: config.dryRun,
        force: config.force,
        verbose: config.verbose,
      );
      return delegator.generate(config);
    }

    if (config.appendToExisting) {
      final entityName = config.repo != null
          ? config.repo!.replaceAll('Repository', '')
          : config.name;
      final entitySnake = StringUtils.camelToSnake(entityName);
      final mockPath = path.join(
        outputDir,
        'data',
        'datasources',
        entitySnake,
        '${entitySnake}_mock_datasource.dart',
      );

      if (File(mockPath).existsSync()) {
        return mockBuilder.generate(config);
      }
      return [];
    }

    if (!config.generateMock && !config.generateMockDataOnly) {
      return [];
    }
    return mockBuilder.generate(config);
  }
}
