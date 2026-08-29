/// The built-in slice plugin (feature 043): context-isolated codebase
/// extraction.
///
/// Extends [ZuraffaPlugin] directly (like `SkeletonPlugin`) rather than
/// [FileGeneratorPlugin] — the slice plugin does not generate architecture
/// code from entities; it extracts existing code into runnable sandboxes
/// (research R-007). Implements [CliAwarePlugin] so the `zfa slice` command
/// tree is registered with the CLI runner automatically.
library;

import 'package:args/command_runner.dart';

import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import 'capabilities/cut_slice_capability.dart';
import 'slice_command.dart';

/// The built-in slice plugin.
class SlicePlugin extends ZuraffaPlugin implements CliAwarePlugin {
  /// Creates the slice plugin.
  SlicePlugin({this.projectRoot = '.'});

  /// Root of the project the plugin operates on ('.' for CLI use; tests
  /// inject a fixture directory).
  final String projectRoot;

  @override
  String get id => 'slice';

  @override
  String get name => 'Slice';

  @override
  String get version => '1.0.0';

  @override
  List<String> get runAfter => const [];

  /// `.zfa.json` integration: `"sliceByDefault": true` enables the slice
  /// plugin in the default plugin set (T071).
  @override
  String? get configKey => 'sliceByDefault';

  /// Schema of the slice plugin's `.zfa.json` section (T071).
  @override
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'sliceByDefault': {
        'type': 'boolean',
        'default': false,
        'description': 'Enable the slice plugin in the default toolchain',
      },
      'default-depth': {
        'type': 'string',
        'enum': ['view', 'presentation', 'feature', 'full'],
        'default': 'feature',
        'description': 'Extraction depth used when --depth is omitted',
      },
    },
  };

  /// Capabilities exposed by this plugin.
  @override
  List<ZuraffaCapability> get capabilities => [CutSliceCapability()];

  /// The `zfa slice` command (FR-011 / INV-1).
  @override
  Command<void> createCommand() => SliceCommand(projectRoot: projectRoot);
}
