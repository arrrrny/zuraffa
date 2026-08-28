// SPDX-License-Identifier: MIT
//
// DiBinding — bind a (possibly shared) [StandardCommand]'s handler to the
// host app's DI container so the handler can resolve its domain dependencies
// (FR-007).
//
// The handler declares its dependencies as a list of [DependencyRequest]s
// (each a name + an expected runtime type). [DiBinding.bind] wires the
// handler to the host's [DiContainer] (an abstract type the host implements,
// typically wrapping `GetIt`), producing a new [StandardCommand] whose
// handler resolves its deps from the host DI before invoking the original.
//
// This keeps commands portable: the same SharedCommand definition can be
// reused across apps that use different DI containers, because each host
// binds the dependencies from its own container.
//
// Pure-Dart (FR-012). The [DiContainer] abstraction avoids a hard dependency
// on `package:get_it` at the type level — apps that use GetIt register a
// [GetItDiContainer] adapter; apps that use a different DI register their
// own adapter.

import 'dart:async';

import 'command_model.dart';
import 'edge_cases.dart';
import 'shared_command.dart';

/// A request for a dependency, declared by a command's handler (FR-007).
///
/// The handler binds its dependencies through a [DiBinding] rather than
/// reaching into a global singleton, so the same [SharedCommand] can run in
/// different apps with different DI configurations.
class DependencyRequest {
  const DependencyRequest({required this.name, required this.expectedType});

  /// The name the handler uses to look up the dependency in the host's DI.
  /// For GetIt, this is the type name (e.g. `'UserRepository'`).
  final String name;

  /// The expected runtime type of the dependency, for runtime validation.
  /// Mismatches between the declared and the actual type throw
  /// [BindingException].
  final Type expectedType;
}

/// The DI container abstraction — apps implement this for their DI of choice
/// (GetIt, Provider, injectable, hand-rolled). The standard CLI plugin only
/// depends on this abstraction, never on a specific DI package.
abstract class DiContainer {
  /// Resolve a dependency by name. Throws if the name is not registered.
  Object? resolve(String name);

  /// Whether a dependency named [name] is registered.
  bool has(String name);
}

/// Binds a [SharedCommand]'s handler to a host app's [DiContainer] (FR-007).
///
/// The original handler is wrapped: before it runs, every declared
/// [DependencyRequest] is resolved from the host's [DiContainer] and made
/// available via [BoundInvocation.dependencies]. If any dependency cannot be
/// resolved, a [BindingException] is thrown before the handler runs.
class DiBinding {
  const DiBinding({required this.dependencies, required this.boundHandler});

  /// Construct a DiBinding from a list of [DependencyRequest]s and a
  /// handler that receives the resolved dependencies.
  factory DiBinding.forHandler({
    required List<DependencyRequest> dependencies,
    required Future<CommandResult> Function(BoundInvocation) boundHandler,
  }) {
    return DiBinding(dependencies: dependencies, boundHandler: boundHandler);
  }

  /// The dependencies this binding requires from the host DI.
  final List<DependencyRequest> dependencies;

  /// The handler that receives the resolved dependencies.
  final Future<CommandResult> Function(BoundInvocation) boundHandler;

  /// Bind to the host's [DiContainer], returning a new [StandardCommand]
  /// whose handler resolves [dependencies] from [container] before invoking
  /// [boundHandler].
  ///
  /// Throws [BindingException] when a dependency is missing. Type mismatches
  /// are detected by attempting a cast through [_TypeChecker] (subtypes are
  /// accepted; only exact-name mismatches raise). This is intentionally
  /// lenient: the handler's own cast is the source of truth for type safety.
  StandardCommand bind(SharedCommand shared, {required DiContainer container}) {
    final original = shared.command;
    return StandardCommand(
      name: original.name,
      description: original.description,
      arguments: original.arguments,
      flags: original.flags,
      aliases: original.aliases,
      handler: (invocation) async {
        final resolved = <String, Object?>{};
        for (final dep in dependencies) {
          if (!container.has(dep.name)) {
            throw BindingException(
              commandName: original.name,
              dependencyName: dep.name,
              reason: 'not registered in host DI',
            );
          }
          final value = container.resolve(dep.name);
          // Soft type check: only raise BindingException for gross mismatches
          // (when the declared type is concrete AND the resolved value's
          // type name differs). Subtype relationships are accepted. This
          // intentionally lets the handler's own cast be the source of
          // truth for type safety, per the principle "the binding resolves
          // by name; the handler validates by type."
          if (value != null &&
              dep.expectedType != Object &&
              dep.expectedType != dynamic) {
            final expectedName = dep.expectedType.toString();
            final actualName = value.runtimeType.toString();
            // Only raise when the expected type is concrete (not abstract)
            // AND the actual is not a subtype. Without runtime subtype
            // introspection, we use name-prefix matching: a registered
            // UserRepositoryImpl satisfies a UserRepository request when
            // the actual type name starts with the expected type name.
            if (!_satisfies(actualName, expectedName)) {
              throw BindingException(
                commandName: original.name,
                dependencyName: dep.name,
                reason: 'expected $expectedName, got $actualName',
              );
            }
          }
          resolved[dep.name] = value;
        }
        return boundHandler(
          BoundInvocation(invocation: invocation, dependencies: resolved),
        );
      },
    );
  }
}

/// Heuristic subtype check based on type name.
///
/// Returns true when [actualName] equals [expectedName] OR starts with
/// [expectedName] (the `Impl` / `Mock` suffix convention). Used by
/// [DiBinding.bind] for soft type validation; not a substitute for the
/// handler's own cast.
bool _satisfies(String actualName, String expectedName) {
  if (actualName == expectedName) return true;
  // Common impl conventions: `<Expected>Impl`, `<Expected>Mock`, etc.
  if (actualName.startsWith(expectedName)) return true;
  // Allow the reverse (expected is concrete, actual is abstract base).
  if (expectedName.startsWith(actualName)) return true;
  return false;
}

/// The invocation passed to a [DiBinding.boundHandler] (FR-007).
///
/// Adds a [dependencies] map to the original [CliInvocation], carrying the
/// resolved instances from the host's [DiContainer].
class BoundInvocation {
  const BoundInvocation({required this.invocation, required this.dependencies});

  /// The original invocation, with its parsed args and flags.
  final CliInvocation invocation;

  /// The resolved dependencies, keyed by [DependencyRequest.name].
  final Map<String, Object?> dependencies;
}
