// SPDX-License-Identifier: MIT
//
// CrossAppInvoker — invoke another app's registered command by name through
// the registry, with NO hard compile-time dependency on the other app
// (FR-005, SC-003).
//
// The invoker only depends on [CommandRegistry] and [StandardCommand] types
// — it never references the host app's command classes directly. App B can
// invoke App A's `greet` command by calling
// `invoker.invoke('appA', 'greet', invocation)` without ever importing
// App A's command class.
//
// Circular reference detection (FR-009 edge case 4) uses a per-isolate
// stack of in-flight invocations; when a new invocation's key is already on
// the stack, a [CircularReferenceException] is raised.
//
// Pure-Dart (FR-012).

import 'package:meta/meta.dart';

import 'command_model.dart';
import 'command_registry.dart';
import 'edge_cases.dart';

/// Invokes another app's registered command by name through the registry
/// (FR-005).
class CrossAppInvoker {
  /// Construct an invoker bound to a [CommandRegistry].
  ///
  /// Multiple invokers may share a registry; the registry is the source of
  /// truth for what commands are available.
  CrossAppInvoker(this.registry);

  /// The registry this invoker consults.
  final CommandRegistry registry;

  /// Per-isolate stack of in-flight invocations, for circular-reference
  /// detection (FR-009 edge case 4).
  ///
  /// Each entry is a `'ownerApp/name'` string. When a new invocation's key
  /// is already on the stack, a [CircularReferenceException] is raised
  /// instead of dispatching.
  static final List<String> _invocationStack = [];

  /// Invoke `[ownerApp]/[commandName]` with the given [CliInvocation].
  ///
  /// Throws:
  /// - [ReferencedAppMissingException] if [ownerApp] has no commands
  ///   registered at all.
  /// - [UnknownCommandException] if the command name is not registered
  ///   under [ownerApp].
  /// - [CircularReferenceException] if the invocation chain has a cycle.
  ///
  /// Returns the [CommandResult] from the command's handler.
  Future<CommandResult> invoke(
    String ownerApp,
    String commandName,
    CliInvocation invocation,
  ) async {
    // Detect app-missing first (FR-009 edge case 3).
    if (registry.enumerateFor(ownerApp).isEmpty) {
      throw ReferencedAppMissingException(
        ownerApp: ownerApp,
        registeredApps: registry
            .enumerate()
            .map((c) => c.ownerApp)
            .toSet()
            .toList(growable: false),
      );
    }
    final entry = registry.require(ownerApp, commandName);
    final key = '$ownerApp/$commandName';

    // Detect circular reference (FR-009 edge case 4).
    if (_invocationStack.contains(key)) {
      throw CircularReferenceException(
        chain: [..._invocationStack, key],
      );
    }

    _invocationStack.add(key);
    try {
      return await entry.command.handler(invocation);
    } finally {
      // Pop only if we pushed (we did, above).
      if (_invocationStack.isNotEmpty && _invocationStack.last == key) {
        _invocationStack.removeLast();
      }
    }
  }

  /// Invoke by name only, when the caller does not specify the owner app.
  ///
  /// If exactly one owner app has registered a command named [commandName],
  /// dispatch to it. If two or more have, throw [AmbiguousCommandException]
  /// (FR-009 edge case 2). If none have, throw [UnknownCommandException].
  Future<CommandResult> invokeByName(
    String commandName,
    CliInvocation invocation,
  ) async {
    final matches = registry.enumerateByName(commandName);
    if (matches.isEmpty) {
      throw UnknownCommandException(
        commandName: commandName,
        availableCommands: registry.enumerate().map((c) => c.key.toString()).toList(),
      );
    }
    if (matches.length > 1) {
      throw AmbiguousCommandException(
        commandName: commandName,
        matches: matches.map((m) => m.key.toString()).toList(growable: false),
      );
    }
    return invoke(matches.first.ownerApp, commandName, invocation);
  }

  /// Whether the invoker currently has any in-flight invocations on the
  /// stack. Useful for tests of the circular-reference detector.
  bool get hasInFlightInvocations => _invocationStack.isNotEmpty;

  /// The current invocation chain, for diagnostics. Empty when no
  /// invocations are in flight.
  List<String> get currentChain => List.unmodifiable(_invocationStack);

  /// Reset the invocation stack. Used by tests between scenarios; never
  /// call this from production code (it would defeat circular-reference
  /// detection).
  @visibleForTesting
  static void resetForTest() => _invocationStack.clear();
}
