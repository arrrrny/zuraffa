// SPDX-License-Identifier: MIT
//
// SharedCommand — share and reuse command definitions across apps (FR-006).
//
// A [SharedCommand] is a [StandardCommand] plus a version string. Apps publish
// a SharedCommand to the registry via [share]; other apps retrieve it via
// [retrieve] and run it through the standard interface with no per-app
// reimplementation.
//
// Version checking (FR-009 edge case 5) rejects a retrieve that requests a
// minimum version higher than the published version. The version string is
// a simplified SemVer (major.minor.patch); pre-release tags are not supported
// in v1.
//
// Pure-Dart (FR-012).

import 'package:meta/meta.dart';

import 'command_model.dart';
import 'command_registry.dart';
import 'edge_cases.dart';

/// A [StandardCommand] published for cross-app reuse (FR-006).
///
/// Add a [version] to a [StandardCommand] and publish it via [share] to make
/// it discoverable by other apps. Retrieval via [retrieve] checks the
/// version constraint and throws [VersionMismatchException] on mismatch.
@immutable
class SharedCommand {
  const SharedCommand({
    required this.command,
    required this.version,
  });

  /// Construct a SharedCommand from a [StandardCommand] and a version string.
  factory SharedCommand.of(
    StandardCommand command, {
    String version = '0.1.0',
  }) {
    return SharedCommand(command: command, version: version);
  }

  /// The command definition being shared.
  final StandardCommand command;

  /// The version of this shared definition. Must be a simplified SemVer
  /// (e.g. `'1.0.0'`). Used by [retrieve]'s `minVersion` check.
  final String version;

  /// Publish this shared command to a [CommandRegistry] under the command's
  /// name and the given owner app.
  ///
  /// Subsequent [retrieve] calls by other apps will find this command at the
  /// published [version]. Throws [CommandAlreadyRegistered] if the same
  /// `(ownerApp, name)` key is already registered.
  void share(CommandRegistry registry, {required String ownerApp}) {
    registry.register(command, ownerApp: ownerApp, version: version);
  }

  /// Retrieve a shared command from a [CommandRegistry] by name.
  ///
  /// Returns the [SharedCommand] view of the registered command, or throws
  /// [UnknownCommandException] if no command is registered under [ownerApp]
  /// / [commandName]. If [minVersion] is provided, throws
  /// [VersionMismatchException] when the published version is below the
  /// minimum.
  static SharedCommand retrieve(
    CommandRegistry registry, {
    required String ownerApp,
    required String commandName,
    String? minVersion,
  }) {
    final entry = registry.require(ownerApp, commandName);
    if (minVersion != null && !_versionSatisfies(entry.version, minVersion)) {
      throw VersionMismatchException(
        commandName: commandName,
        ownerApp: ownerApp,
        requestedMinVersion: minVersion,
        publishedVersion: entry.version,
      );
    }
    return SharedCommand(command: entry.command, version: entry.version);
  }

  /// Compare two simplified SemVer strings. Returns true if [published] is
  /// greater than or equal to [minimum].
  ///
  /// Simplified SemVer: `major.minor.patch` where each component is a
  /// non-negative integer. Pre-release tags are not supported in v1.
  @visibleForTesting
  static bool versionSatisfies(String published, String minimum) =>
      _versionSatisfies(published, minimum);

  static bool _versionSatisfies(String published, String minimum) {
    final p = _parseSemVer(published);
    final m = _parseSemVer(minimum);
    if (p == null || m == null) {
      // Unparseable: be lenient, allow the retrieval. The audit will flag.
      return true;
    }
    if (p[0] != m[0]) return p[0] > m[0];
    if (p[1] != m[1]) return p[1] > m[1];
    return p[2] >= m[2];
  }

  static List<int>? _parseSemVer(String s) {
    final parts = s.split('.');
    if (parts.length != 3) return null;
    try {
      return parts.map(int.parse).toList(growable: false);
    } on FormatException {
      return null;
    }
  }
}
