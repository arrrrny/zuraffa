// SPDX-License-Identifier: MIT
//
// Edge cases for the standard CLI plugin (FR-009).
//
// Six typed exceptions covering the edge cases the spec mandates:
//   1. Unknown / mistyped command
//   2. Ambiguous / conflicting command names (when invoking by name only)
//   3. Referenced command or app missing
//   4. Circular command references
//   5. Version mismatch between sharing apps
//   6. Non-CLI / non-interactive context
//
// Each maps to a specific exit code from [CliContract.exitCode] and a specific
// error-shape `code` string emitted in JSON output. [CliApp] catches each
// typed exception, emits the contract error shape, and exits with the matching
// code.
//
// Pure-Dart (FR-012).

import 'command_registry.dart';

/// Base class for all standard-CLI edge-case exceptions.
///
/// Subclasses carry the metadata the audit and the help screen need to give
/// the user a precise diagnostic. Every [CliEdgeCaseException] has a [code]
/// (one of the [CliExitCodes] vocabulary names) and a [details] map for the
/// JSON error shape.
sealed class CliEdgeCaseException implements Exception {
  const CliEdgeCaseException();

  /// The error code, one of the [CliExitCodes] vocabulary names as a string
  /// (e.g. `'notFound'`, `'conflict'`). Used in the JSON error shape's
  /// `code` field and translated to the contract exit code by [CliApp].
  String get code;

  /// Human-readable error message.
  String get message;

  /// Additional context for the JSON error shape's `details` field.
  Map<String, Object?> get details;

  @override
  String toString() => '$runtimeType: $message';
}

/// The requested command is not registered under any owner app (FR-009
/// edge case 1: unknown / mistyped command).
///
/// Carries the unknown command name and a hint listing the available
/// commands so the user can correct the typo.
class UnknownCommandException extends CliEdgeCaseException {
  const UnknownCommandException({
    required this.commandName,
    this.ownerApp,
    required this.availableCommands,
  });

  /// The command name the user typed.
  final String commandName;

  /// The owner app the user specified (may be null when invoking by name
  /// only).
  final String? ownerApp;

  /// The list of available commands, as `'ownerApp/name'` strings, for the
  /// help hint.
  final List<String> availableCommands;

  @override
  String get code => 'notFound';

  @override
  String get message {
    final owner = ownerApp == null ? '' : ' in app "$ownerApp"';
    return 'Command "$commandName" not found$owner. '
        'Available commands: ${availableCommands.join(', ')}.';
  }

  @override
  Map<String, Object?> get details => {
        'commandName': commandName,
        if (ownerApp != null) 'ownerApp': ownerApp,
        'availableCommands': availableCommands,
      };
}

/// Two or more owner apps have registered a command with the same name, and
/// the caller invoked by name only (without specifying an owner app) (FR-009
/// edge case 2: ambiguous / conflicting command names).
///
/// Carries the ambiguous name and the list of matching `(ownerApp, name)`
/// pairs so the user can disambiguate by specifying the owner app.
class AmbiguousCommandException extends CliEdgeCaseException {
  const AmbiguousCommandException({
    required this.commandName,
    required this.matches,
  });

  /// The ambiguous command name.
  final String commandName;

  /// The list of matching registered commands, as `'ownerApp/name'` strings.
  final List<String> matches;

  @override
  String get code => 'conflict';

  @override
  String get message =>
      'Command "$commandName" is registered by multiple apps: '
      '${matches.join(', ')}. Specify the owner app as '
      '"<ownerApp> <commandName>" to disambiguate.';

  @override
  Map<String, Object?> get details => {
        'commandName': commandName,
        'matches': matches,
      };
}

/// The owner app referenced by a cross-app invocation is not registered (FR-009
/// edge case 3: referenced command or app missing).
class ReferencedAppMissingException extends CliEdgeCaseException {
  const ReferencedAppMissingException({
    required this.ownerApp,
    required this.registeredApps,
  });

  /// The owner app that was referenced but is not registered.
  final String ownerApp;

  /// The list of registered owner apps, for the help hint.
  final List<String> registeredApps;

  @override
  String get code => 'notFound';

  @override
  String get message =>
      'App "$ownerApp" is not registered. Registered apps: '
      '${registeredApps.join(', ')}.';

  @override
  Map<String, Object?> get details => {
        'ownerApp': ownerApp,
        'registeredApps': registeredApps,
      };
}

/// A cross-app invocation chain detected a cycle (FR-009 edge case 4:
/// circular command references).
///
/// Carries the chain of `(ownerApp, commandName)` pairs that formed the cycle,
/// so the user can see exactly where the loop is.
class CircularReferenceException extends CliEdgeCaseException {
  const CircularReferenceException({required this.chain});

  /// The chain of invocations that formed the cycle, in order, starting from
  /// the original caller. The last entry is the one that closed the cycle.
  /// Each entry is a `'ownerApp/name'` string.
  final List<String> chain;

  @override
  String get code => 'circularRef';

  @override
  String get message =>
      'Circular reference detected: ${chain.join(' -> ')}.';

  @override
  Map<String, Object?> get details => {
        'chain': chain,
      };
}

/// A shared command was requested at a minimum version, but the published
/// version is below that minimum (FR-009 edge case 5: version mismatch
/// between sharing apps).
class VersionMismatchException extends CliEdgeCaseException {
  const VersionMismatchException({
    required this.commandName,
    required this.ownerApp,
    required this.requestedMinVersion,
    required this.publishedVersion,
  });

  /// The command whose version is mismatched.
  final String commandName;

  /// The owner app that published the command.
  final String ownerApp;

  /// The minimum version the caller requested.
  final String requestedMinVersion;

  /// The version the owner app actually published.
  final String publishedVersion;

  @override
  String get code => 'versionMismatch';

  @override
  String get message =>
      'Command "$ownerApp/$commandName" version $publishedVersion does not '
      'satisfy the requested minimum $requestedMinVersion.';

  @override
  Map<String, Object?> get details => {
        'commandName': commandName,
        'ownerApp': ownerApp,
        'requestedMinVersion': requestedMinVersion,
        'publishedVersion': publishedVersion,
      };
}

/// A command requires interaction with the user, but stdout is piped or
/// stdin is not a TTY (FR-009 edge case 6: non-CLI / non-interactive context).
class NonInteractiveContextException extends CliEdgeCaseException {
  const NonInteractiveContextException({
    required this.commandName,
    required this.reason,
  });

  /// The command that required interaction.
  final String commandName;

  /// Why the context is non-interactive (e.g. `'stdout is piped'`).
  final String reason;

  @override
  String get code => 'usage';

  @override
  String get message =>
      'Command "$commandName" requires an interactive terminal, but $reason.';

  @override
  Map<String, Object?> get details => {
        'commandName': commandName,
        'reason': reason,
      };
}

/// Raised by [CommandRegistry.register] when an app tries to register a
/// command whose `(ownerApp, name)` key is already registered.
///
/// This is the namespacing rule from FR-009 edge case 2 at registration time:
/// the same app re-registering the same command is a bug; two different apps
/// registering the same command name coexist under different `ownerApp`s.
class CommandAlreadyRegistered extends CliEdgeCaseException {
  const CommandAlreadyRegistered(this.key, {this.existingVersion});

  /// The key that was already registered.
  final RegistryKey key;

  /// The version of the existing registration, for diagnostics.
  final String? existingVersion;

  @override
  String get code => 'conflict';

  @override
  String get message =>
      'Command $key is already registered'
      '${existingVersion == null ? '' : ' (version $existingVersion)'}. '
      'Use a different name or unregister first.';

  @override
  Map<String, Object?> get details => {
        'key': key.toString(),
        if (existingVersion != null) 'existingVersion': existingVersion,
      };
}

/// Raised by [DiBinding.bind] when a handler's declared dependency is not
/// registered in the host app's DI container.
class BindingException extends CliEdgeCaseException {
  const BindingException({
    required this.commandName,
    required this.dependencyName,
    required this.reason,
  });

  /// The command whose binding failed.
  final String commandName;

  /// The dependency that could not be resolved.
  final String dependencyName;

  /// Why the binding failed (e.g. `'not registered in host DI'`).
  final String reason;

  @override
  String get code => 'runtime';

  @override
  String get message =>
      'Binding "$dependencyName" for command "$commandName" failed: $reason.';

  @override
  Map<String, Object?> get details => {
        'commandName': commandName,
        'dependencyName': dependencyName,
        'reason': reason,
      };
}
