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
// ONE parameterized capability replaces the eight copy-pasted per-plugin
// clones (collapsed via the #1149 kill list; spec 1023 fixes the contract
// name to `FeatureLayerCapability(layer:)`). The MCP-visible capability
// names are unchanged.
import 'capabilities/feature_layer_capability.dart';
// Spec 1115 (merged from master): the xray capability is NOT one of the
// 8 parameterized clones — its `feature` argument is a TYPED FeatureId
// validated against registered contracts, so it keeps its own class.
import 'xray_feature_capability.dart';

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

  /// Spec 1023: the registered layer matrix — one row per generated-
  /// artifact layer served by the ONE parameterized
  /// `FeatureLayerCapability`. The capability manifest (the `capabilities`
  /// getter below) is built FROM this matrix, so the layer set, the
  /// per-layer descriptions and the registration order are declared in
  /// exactly one place. Row order is the pre-parameterization manifest
  /// order and MUST NOT change (manifest parity contract).
  static const List<
    ({String layer, String description, bool mapsMockArgToUseMock})
  >
  _layerMatrix = [
    (
      layer: 'route',
      description: 'Add routes to an existing feature',
      mapsMockArgToUseMock: false,
    ),
    (
      layer: 'di',
      description: 'Add dependency injection to an existing feature',
      mapsMockArgToUseMock: true,
    ),
    (
      layer: 'mock',
      description: 'Add mock data to an existing feature',
      mapsMockArgToUseMock: false,
    ),
    (
      layer: 'test',
      description: 'Add tests to an existing feature',
      mapsMockArgToUseMock: false,
    ),
    (
      layer: 'view',
      description: 'Add view to an existing feature',
      mapsMockArgToUseMock: false,
    ),
    (
      layer: 'presenter',
      description: 'Add presenter to an existing feature',
      mapsMockArgToUseMock: false,
    ),
    (
      layer: 'controller',
      description: 'Add controller to an existing feature',
      mapsMockArgToUseMock: false,
    ),
    (
      layer: 'state',
      description: 'Add state to an existing feature',
      mapsMockArgToUseMock: false,
    ),
  ];

  @override
  List<ZuraffaCapability> get capabilities => [
    ScaffoldFeatureCapability(this),
    // One parameterized capability, registered once per layer-matrix row.
    // Per-layer names, descriptions, schemas and execution behavior are
    // identical to the pre-parameterization manifest.
    for (final row in _layerMatrix)
      FeatureLayerCapability(
        this,
        layer: row.layer,
        description: row.description,
        mapsMockArgToUseMock: row.mapsMockArgToUseMock,
      ),
    // Spec 1115 (issue #1115 item 6): the xray capability — its `feature`
    // argument is a TYPED FeatureId validated against the registered
    // contracts.
    XrayFeatureCapability(this),
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
