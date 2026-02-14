import 'package:args/command_runner.dart';
import '../../commands/state_command.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/state_builder.dart';

class StatePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  late final StateBuilder stateBuilder;

  StatePlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  }) {
    stateBuilder = StateBuilder(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
  }

  @override
  Command createCommand() => StateCommand(this);

  @override
  String get id => 'state';

  @override
  String get name => 'State Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (config.outputDir != outputDir ||
        config.dryRun != dryRun ||
        config.force != force ||
        config.verbose != verbose) {
      final delegator = StatePlugin(
        outputDir: config.outputDir,
        dryRun: config.dryRun,
        force: config.force,
        verbose: config.verbose,
      );
      return delegator.generate(config);
    }

    if (!config.generateState) {
      return [];
    }
    final file = await stateBuilder.generate(config);
    return [file];
  }
}
