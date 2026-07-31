import 'dart:collection';

/// Lightweight dependency-injection container for zuraffa.
///
/// Replaces manual `get_it` setup. Populated by the generated
/// `zuraffa_injection.g.dart` file.
///
/// ```dart
/// final container = ZuraffaContainer.instance;
/// final repo = container.resolve<ProductRepository>();
/// ```
class ZuraffaContainer {
  ZuraffaContainer._();
  static final ZuraffaContainer instance = ZuraffaContainer._();

  final _registrations = HashMap<Type, _Registration>();
  final _singletons = HashMap<Type, dynamic>();
  final _lazy = HashMap<Type, dynamic>();

  /// Register a factory for type [T].
  void registerFactory<T>(T Function() factory) {
    _registrations[T] = _Registration(
      factory: factory,
      scope: _Scope.transient,
    );
  }

  /// Register a singleton for type [T].
  void registerSingleton<T>(T Function() factory) {
    _registrations[T] = _Registration(
      factory: factory,
      scope: _Scope.singleton,
    );
  }

  /// Register a lazy singleton for type [T].
  void registerLazySingleton<T>(T Function() factory) {
    _registrations[T] = _Registration(factory: factory, scope: _Scope.lazy);
  }

  /// Register an instance directly (useful for testing/mocking).
  void registerInstance<T>(T instance) {
    _singletons[T] = instance;
    _registrations[T] = _Registration(
      factory: () => instance,
      scope: _Scope.singleton,
    );
  }

  /// Resolve a dependency of type [T].
  ///
  /// Throws [StateError] if [T] is not registered.
  T resolve<T>() {
    final reg = _registrations[T];
    if (reg == null) {
      throw StateError(
        'No registration found for type $T. '
        'Did you run `zfa build` and import zuraffa_injection.g.dart?',
      );
    }

    switch (reg.scope) {
      case _Scope.transient:
        return reg.factory() as T;
      case _Scope.singleton:
        return _singletons.putIfAbsent(T, reg.factory) as T;
      case _Scope.lazy:
        return _lazy.putIfAbsent(T, reg.factory) as T;
    }
  }

  /// Whether type [T] is registered.
  bool isRegistered<T>() => _registrations.containsKey(T);

  /// Clear all registrations. Primarily for testing.
  void reset() {
    _registrations.clear();
    _singletons.clear();
    _lazy.clear();
  }
}

enum _Scope { transient, singleton, lazy }

class _Registration {
  _Registration({required this.factory, required this.scope});
  final dynamic Function() factory;
  final _Scope scope;
}
