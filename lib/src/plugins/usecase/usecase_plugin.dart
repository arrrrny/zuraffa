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
    GeneratorOptions options = const GeneratorOptions(),
    @Deprecated('Use options.dryRun') bool? dryRun,
    @Deprecated('Use options.force') bool? force,
    @Deprecated('Use options.verbose') bool? verbose,
  }) : options = options.copyWith(
         dryRun: dryRun ?? options.dryRun,
         force: force ?? options.force,
         verbose: verbose ?? options.verbose,
       ) {
    entityGenerator = EntityUseCaseGenerator(
      outputDir: outputDir,
      options: this.options,
    );
    customGenerator = CustomUseCaseGenerator(
      outputDir: outputDir,
      options: this.options,
    );
    streamGenerator = StreamUseCaseGenerator(
      outputDir: outputDir,
      options: this.options,
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
    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose) {
      final delegator = UseCasePlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
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
      final file = await customGenerator.generateOrchestrator(config);
      return [file];
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
