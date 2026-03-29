import 'package:args/command_runner.dart';
import '../../commands/feature_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'capabilities/scaffold_feature_capability.dart';
import 'capabilities/route_feature_capability.dart';
import 'capabilities/di_feature_capability.dart';
import 'capabilities/mock_feature_capability.dart';
import 'capabilities/test_feature_capability.dart';
import 'capabilities/view_feature_capability.dart';
import 'capabilities/presenter_feature_capability.dart';
import 'capabilities/controller_feature_capability.dart';
import 'capabilities/state_feature_capability.dart';

/// Manages high-level feature scaffolding.
///
/// Coordinates multiple plugins to generate a complete feature slice,
/// including domain, data, and presentation layers in one command.
///
/// Example:
/// ```dart
/// final plugin = FeaturePlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Product'));
/// ```
class FeaturePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;

  FeaturePlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  });

  @override
  List<ZuraffaCapability> get capabilities => [
    ScaffoldFeatureCapability(this),
    RouteFeatureCapability(this),
    DiFeatureCapability(this),
    MockFeatureCapability(this),
    TestFeatureCapability(this),
    ViewFeatureCapability(this),
    PresenterFeatureCapability(this),
    ControllerFeatureCapability(this),
    StateFeatureCapability(this),
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
  JsonSchema get configSchema => {'type': 'object', 'properties': {}};

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    return [];
  }

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    // Feature plugin itself doesn't generate files directly via this method
    // in the traditional sense, but delegates to the capability logic.
    // However, if called via legacy flow, we might need logic here.
    // For now, return empty list as it's primarily a capability provider.
    return [];
  }
}
