import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import '../../commands/mock_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/string_utils.dart';
import 'builders/mock_builder.dart';
import 'capabilities/create_mock_capability.dart';

/// Manages mock data and provider generation for testing.
///
/// Builds mock implementations of data sources and providers, along with
/// sample data generators to facilitate offline development and unit testing.
///
/// Example:
/// ```dart
/// final plugin = MockPlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Auth'));
/// ```
class MockPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final MockBuilder mockBuilder;

  MockPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  }) {
    mockBuilder = MockBuilder(outputDir: outputDir, options: options);
  }

  @override
  List<ZuraffaCapability> get capabilities => [CreateMockCapability(this)];

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
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose ||
        config.revert != options.revert) {
      final delegator = MockPlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
          revert: config.revert,
        ),
      );
      return delegator.generate(config);
    }

    // If mocks were explicitly requested, always generate/append
    if (config.generateMock || config.generateMockDataOnly) {
      // Only generate if we are also generating data/datasource/repository OR if they already exist
      if (config.generateData || config.generateDataSource || config.generateRepository) {
        return mockBuilder.generate(config);
      }
      
      // If not generating data layers now, check if we are in append mode and files exist
      if (config.appendToExisting) {
        // Fall through to existing logic
      } else {
        // Don't generate mocks if we are just doing presentation layer and no data layer exists
        return [];
      }
    }

    // If not explicitly requested, only run if we are appending to existing mocks
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

      final providerSnake = config.providerSnake;
      if (providerSnake != null) {
        final providerMockPath = path.join(
          outputDir,
          'data',
          'providers',
          config.effectiveDomain,
          '${providerSnake}_mock_provider.dart',
        );
        if (File(providerMockPath).existsSync()) {
          return mockBuilder.generate(config);
        }
      }

      if (File(mockPath).existsSync()) {
        return mockBuilder.generate(config);
      }
    }

    return [];
  }
}
