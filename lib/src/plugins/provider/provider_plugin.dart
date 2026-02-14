import 'package:args/command_runner.dart';
import '../../commands/provider_command.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/provider_builder.dart';

class ProviderPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  late final ProviderBuilder providerBuilder;

  ProviderPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  }) {
    providerBuilder = ProviderBuilder(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
  }

  @override
  Command createCommand() => ProviderCommand(this);

  @override
  String get id => 'provider';

  @override
  String get name => 'Provider Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (config.outputDir != outputDir ||
        config.dryRun != dryRun ||
        config.force != force ||
        config.verbose != verbose) {
      final delegator = ProviderPlugin(
        outputDir: config.outputDir,
        dryRun: config.dryRun,
        force: config.force,
        verbose: config.verbose,
      );
      return delegator.generate(config);
    }

    if (!config.hasService || !config.generateData) {
      return [];
    }

    final file = await providerBuilder.generate(config);
    return [file];
  }
}
