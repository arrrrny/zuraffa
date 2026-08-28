// SPDX-License-Identifier: MIT
//
// CliPlugin — native, built-in Zuraffa package registration (FR-010).
//
// The standard CLI plugin is a native, built-in Zuraffa package: it lives
// inside the `zuraffa` pub package (at `lib/src/cli/standard/`) rather than
// being a separate third-party bolt-on. Apps discover and adopt it via the
// public exports in `lib/zuraffa.dart`.
//
// This file provides a single [CliPlugin] metadata class — the runtime
// library is the rest of `lib/src/cli/standard/`. The class exists so the
// plugin is discoverable through the same plugin loader the rest of Zuraffa
// uses (lib/src/cli/plugin_loader.dart) and through `zfa plugin list`.
//
// The generator-side of the plugin (which produces standardized CLI commands
// for an entity) is at `lib/src/plugins/cli/cli_plugin.dart` and is a
// separate class extending `ZuraffaPlugin`.
//
// Pure-Dart (FR-012): no `package:flutter` import anywhere in this file.

import 'package:meta/meta.dart';

/// Metadata for the native, built-in standard CLI plugin (FR-010).
///
/// Discoverable via `CliPlugin.instance.id`; not a generator plugin (the
/// generator is `lib/src/plugins/cli/cli_plugin.dart`). The runtime library
/// is the rest of `lib/src/cli/standard/`.
@immutable
class CliPlugin {
  const CliPlugin._();

  /// The singleton instance. The plugin is stateless; one instance suffices.
  static const CliPlugin instance = CliPlugin._();

  /// The plugin's unique id, matching the convention `'<name>'` used by
  /// other plugins at `lib/src/plugins/<name>/<name>_plugin.dart`.
  static const String pluginId = 'cli';

  /// The plugin's human-readable name.
  static const String pluginName = 'Standard CLI Plugin';

  /// The plugin's version, matching the Zuraffa package version.
  static const String pluginVersion = '0.1.0';

  /// The plugin's id (instance accessor for plugin-loader compatibility).
  String get id => pluginId;

  /// The plugin's name (instance accessor).
  String get name => pluginName;

  /// The plugin's version (instance accessor).
  String get version => pluginVersion;
}
