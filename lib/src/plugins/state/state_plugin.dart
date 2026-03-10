import 'package:args/command_runner.dart';
import '../../commands/state_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/state_builder.dart';
import 'capabilities/create_state_capability.dart';

/// Manages UI state class generation for the presentation layer.
///
/// Builds immutable state classes with copyWith, equality, and serialization
/// support to be used with controllers and presenters.
///
/// Example:
/// ```dart
/// final plugin = StatePlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Product'));
/// ```
class StatePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final StateBuilder stateBuilder;

  StatePlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  }) {
    stateBuilder = StateBuilder(outputDir: outputDir, options: options);
  }

  @override
  List<ZuraffaCapability> get capabilities => [CreateStateCapability(this)];

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
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose) {
      final delegator = StatePlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
        ),
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
