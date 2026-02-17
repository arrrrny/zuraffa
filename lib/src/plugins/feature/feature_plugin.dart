import 'package:args/command_runner.dart';
import '../../commands/feature_command.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'capabilities/scaffold_feature_capability.dart';
import '../../core/plugin_system/capability.dart';

class FeaturePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  FeaturePlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  });

  @override
  List<ZuraffaCapability> get capabilities => [
        ScaffoldFeatureCapability(this),
      ];

  @override
  Command createCommand() => FeatureCommand(this);

  @override
  String get id => 'feature';

  @override
  String get name => 'Feature Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    // Feature plugin itself doesn't generate files directly via this method
    // in the traditional sense, but delegates to the capability logic.
    // However, if called via legacy flow, we might need logic here.
    // For now, return empty list as it's primarily a capability provider.
    return [];
  }
}
