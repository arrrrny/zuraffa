// SPDX-License-Identifier: MIT
//
// CommandRegistry — the shared, discoverable catalog of commands across
// Zuraffa apps (FR-004).
//
// Apps register their [StandardCommand]s into a [CommandRegistry] keyed by
// (ownerApp, name). The registry deduplicates by identity and refuses to
// silently override a previously registered (ownerApp, name) pair, raising
// [CommandAlreadyRegistered] instead (FR-009 namespacing edge case).
//
// Cross-app discovery and invocation happens through the registry: App B
// looks up App A's command by name without importing App A's command class
// (FR-005, SC-003).
//
// Pure-Dart (FR-012).

import 'package:meta/meta.dart';

import 'command_model.dart';
import 'edge_cases.dart';

/// A registered command, with its owner app and registration metadata.
///
/// The registry stores [RegisteredCommand]s rather than bare [StandardCommand]s
/// so callers can introspect ownership without losing track of which app
/// owns which command.
@immutable
class RegisteredCommand {
  const RegisteredCommand({
    required this.command,
    required this.ownerApp,
    required this.version,
  });

  /// The command definition.
  final StandardCommand command;

  /// The owning app's name (e.g. `'zuraffa'`, `'zikzak'`).
  final String ownerApp;

  /// The version of the command definition, for cross-app sharing (FR-006).
  /// Defaults to `'0.1.0'` for commands that are not explicitly shared.
  final String version;

  /// The key the registry uses to look up this command.
  RegistryKey get key => RegistryKey(ownerApp, command.name);
}

/// The composite key for the registry: `(ownerApp, name)`.
@immutable
class RegistryKey {
  const RegistryKey(this.ownerApp, this.name);

  final String ownerApp;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegistryKey && ownerApp == other.ownerApp && name == other.name;

  @override
  int get hashCode => Object.hash(ownerApp, name);

  @override
  String toString() => '$ownerApp/$name';
}

/// The shared command registry (FR-004, FR-005, FR-006).
///
/// A single in-memory registry holds every command every Zuraffa app has
/// registered in this process. Apps register commands at startup; the
/// registry deduplicates by [RegistryKey]. Cross-app invocation (FR-005)
/// looks up commands by `(ownerApp, name)` without compile-time coupling.
class CommandRegistry {
  final Map<RegistryKey, RegisteredCommand> _commands = {};

  /// Register a command under `(ownerApp, command.name)`.
  ///
  /// Throws [CommandAlreadyRegistered] if a command with the same key already
  /// exists — this is the FR-009 namespacing rule: two apps registering the
  /// same command name coexist (different `ownerApp`), but the same app
  /// registering the same command name twice is a bug and is rejected.
  void register(
    StandardCommand command, {
    required String ownerApp,
    String version = '0.1.0',
  }) {
    final key = RegistryKey(ownerApp, command.name);
    if (_commands.containsKey(key)) {
      throw CommandAlreadyRegistered(key, existingVersion: _commands[key]!.version);
    }
    _commands[key] = RegisteredCommand(
      command: command,
      ownerApp: ownerApp,
      version: version,
    );
  }

  /// Look up a command by `(ownerApp, name)`.
  ///
  /// Returns the [RegisteredCommand] or `null` if no command is registered
  /// under that key. Callers that want a typed exception for missing
  /// commands should use [require] instead.
  RegisteredCommand? lookup(String ownerApp, String name) {
    return _commands[RegistryKey(ownerApp, name)];
  }

  /// Look up a command, throwing [UnknownCommandException] if missing.
  RegisteredCommand require(String ownerApp, String name) {
    final cmd = lookup(ownerApp, name);
    if (cmd == null) {
      throw UnknownCommandException(
        commandName: name,
        ownerApp: ownerApp,
        availableCommands: enumerate().map((c) => c.key.toString()).toList(),
      );
    }
    return cmd;
  }

  /// Enumerate every registered command, across all owner apps.
  List<RegisteredCommand> enumerate() {
    return _commands.values.toList(growable: false);
  }

  /// Enumerate only the commands owned by [ownerApp].
  List<RegisteredCommand> enumerateFor(String ownerApp) {
    return _commands.values
        .where((c) => c.ownerApp == ownerApp)
        .toList(growable: false);
  }

  /// Enumerate every command named [name] across all owner apps — used to
  /// detect ambiguity when a caller invokes by name only (without specifying
  /// the owner app). If the result has more than one entry, the invocation is
  /// ambiguous and must be namespaced (FR-009).
  List<RegisteredCommand> enumerateByName(String name) {
    return _commands.values
        .where((c) => c.command.name == name)
        .toList(growable: false);
  }

  /// Whether a command is registered under `(ownerApp, name)`.
  bool contains(String ownerApp, String name) {
    return _commands.containsKey(RegistryKey(ownerApp, name));
  }

  /// The number of registered commands.
  int get length => _commands.length;

  /// Remove all registered commands. Useful for tests.
  void clear() => _commands.clear();
}
