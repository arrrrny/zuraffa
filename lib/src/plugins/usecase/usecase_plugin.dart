import 'package:args/command_runner.dart';
import '../../commands/usecase_command.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'generators/custom_usecase_generator.dart';
import 'generators/entity_usecase_generator.dart';
import 'generators/stream_usecase_generator.dart';

class UseCasePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  late final EntityUseCaseGenerator entityGenerator;
  late final CustomUseCaseGenerator customGenerator;
  late final StreamUseCaseGenerator streamGenerator;

  UseCasePlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  }) {
    entityGenerator = EntityUseCaseGenerator(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    customGenerator = CustomUseCaseGenerator(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    streamGenerator = StreamUseCaseGenerator(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
  }

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
        config.dryRun != dryRun ||
        config.force != force ||
        config.verbose != verbose) {
      final delegator = UseCasePlugin(
        outputDir: config.outputDir,
        dryRun: config.dryRun,
        force: config.force,
        verbose: config.verbose,
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
    if (config.isCustomUseCase) {
      if (config.useCaseType == 'stream') {
        return [await streamGenerator.generate(config)];
      }
      return [await customGenerator.generate(config)];
    }
    return [];
  }
}
