import 'package:args/command_runner.dart';
import '../../commands/usecase_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'capabilities/create_usecase_capability.dart';
import 'generators/custom_usecase_generator.dart';
import 'generators/entity_usecase_generator.dart';
import 'generators/stream_usecase_generator.dart';

/// Manages use case generation for the domain layer.
///
/// Coordinates entity-based, custom, and stream use case generators based
/// on the provided configuration.
///
/// Example:
/// ```dart
/// final plugin = UseCasePlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Auth'));
/// ```
class UseCasePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;

  late final EntityUseCaseGenerator entityGenerator;
  late final CustomUseCaseGenerator customGenerator;
  late final StreamUseCaseGenerator streamGenerator;

  UseCasePlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  }) {
    entityGenerator = EntityUseCaseGenerator(
      outputDir: outputDir,
      options: options,
    );
    customGenerator = CustomUseCaseGenerator(
      outputDir: outputDir,
      options: options,
    );
    streamGenerator = StreamUseCaseGenerator(
      outputDir: outputDir,
      options: options,
    );
  }

  @override
  List<ZuraffaCapability> get capabilities => [CreateUseCaseCapability(this)];

  @override
  Command createCommand() => UseCaseCommand(this);

  @override
  String get id => 'usecase';

  @override
  String get name => 'UseCase Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    // If the plugin is being called, we should generate unless explicitly disabled
    // via a flag. Previously we were too restrictive.
    // If revert is true, we ALWAYS proceed.
    // If generateUseCase is true, we ALWAYS proceed.
    // If BOTH are false, we only proceed if we're in a mode where generation is expected
    // when the plugin is enabled.
    if (!config.generateUseCase && !config.revert) {
      // If we are NOT entity-based and NOT custom usecase, something is weird,
      // but let's assume if it's orchestrator/polymorphic it should still generate
      // if those flags are true.
      if (!config.isEntityBased &&
          !config.isCustomUseCase &&
          !config.isOrchestrator &&
          !config.isPolymorphic) {
        return [];
      }
    }

    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose ||
        config.revert != options.revert) {
      final delegator = UseCasePlugin(
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

    if (config.isEntityBased) {
      return entityGenerator.generate(config);
    }
    if (config.isPolymorphic) {
      return customGenerator.generatePolymorphic(config);
    }
    if (config.isOrchestrator) {
      return [await customGenerator.generateOrchestrator(config)];
    }
    if (config.useCaseType == 'stream') {
      return [await streamGenerator.generate(config)];
    }
    if (config.isCustomUseCase) {
      return [await customGenerator.generate(config)];
    }
    return [];
  }
}
