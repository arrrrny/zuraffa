// Helper: minimal DI container for command-binding tests.
//
// Implements the [DiContainer] abstraction so tests can verify [DiBinding]
// without depending on a real GetIt instance.
//
// Pure-Dart (FR-012).

import 'package:zuraffa/zuraffa.dart';

/// A simple in-memory [DiContainer] for tests. Records what was looked up
/// and what was returned.
class FakeDiContainer implements DiContainer {
  final Map<String, Object?> _registered = {};
  final List<String> _lookups = [];

  void register<T>(String name, T instance) {
    _registered[name] = instance;
  }

  @override
  Object? resolve(String name) {
    _lookups.add(name);
    if (!_registered.containsKey(name)) {
      throw StateError('not registered: $name');
    }
    return _registered[name];
  }

  @override
  bool has(String name) => _registered.containsKey(name);

  /// The list of dependency names that were looked up via [resolve].
  List<String> get lookups => List.unmodifiable(_lookups);

  /// The list of registered dependency names.
  Iterable<String> get registeredNames => _registered.keys;
}
