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

  /// Capabilities exposed by this plugin.
  ///
  /// Populated as the TDD cycles land the cut, merge, verify, and export
  /// capabilities.
  @override
  List<ZuraffaCapability> get capabilities => [];

  /// The `zfa slice` command (FR-011 / INV-1).
  @override
  Command<void> createCommand() => SliceCommand(projectRoot: projectRoot);
}
