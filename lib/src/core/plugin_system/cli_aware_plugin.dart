import 'package:args/command_runner.dart';

/// Mixin for plugins that expose a CLI command.
///
/// Plugins implementing this interface will have their commands automatically
/// registered with the main Zuraffa CLI runner.
abstract class CliAwarePlugin {
  /// Creates the [Command] instance for this plugin.
  ///
  /// The returned command should typically extend [PluginCommand] to ensure
  /// consistent behavior and flag handling.
  Command createCommand();
}
