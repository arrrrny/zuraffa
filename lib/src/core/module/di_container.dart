import 'package:get_it/get_it.dart';

/// A lightweight dependency-injection container that wraps [GetIt].
///
/// [ZuraffaDIContainer] provides a thin, typed facade over [GetIt] so
/// that generated DI setup code and micro-frontend plugins can exchange
/// service registrations through a stable contract that does not leak
/// the full [GetIt] API surface.
///
/// The container is constructed with an optional [GetIt] instance. When
/// omitted, [GetIt.instance] is used, making the zero-arg constructor
/// convenient for typical application bootstrap.
///
/// ## Registration methods
///
/// | Method                | Behaviour                                            |
/// |-----------------------|------------------------------------------------------|
/// | [registerLazySingleton] | Resolves lazily on first [get] call; cached thereafter. |
/// | [registerFactory]       | Creates a **new** instance on **every** [get] call.   |
/// | [registerSingleton]     | Creates and caches immediately at registration time.  |
/// | [registerInstance]      | Binds an **already-created** object (useful for     |
/// |                        | test mocks and manual wiring).                       |
///
/// ## Interoperability
///
/// Generated DI registration helpers accept a raw [GetIt] reference.
/// Callers can pass [getIt] directly to bridge between this wrapper
/// and generated code without unwrapping.
///
/// ```dart
/// final di = ZuraffaDIContainer();
///
/// // Manual registration
/// di.registerLazySingleton<MyService>(() => MyServiceImpl());
///
/// // Interop with generated code that expects GetIt
/// generatedRegisterAll(di.getIt);
///
/// final service = di.get<MyService>();
/// ```
class ZuraffaDIContainer {
  /// The underlying [GetIt] instance that backs this container.
  ///
  /// Exposed for interoperability with generated DI helpers that
  /// require a raw [GetIt] parameter. Prefer the typed delegate
  /// methods ([registerLazySingleton], [get], etc.) in application code.
  final GetIt getIt;

  /// Creates a new [ZuraffaDIContainer] wrapping [getIt].
  ///
  /// If [getIt] is `null`, [GetIt.instance] is used. Supplying an
  /// explicit instance is recommended in tests so that each test
  /// gets an isolated container:
  ///
  /// ```dart
  /// final di = ZuraffaDIContainer(GetIt.asynchronousFactory());
  /// ```
  ZuraffaDIContainer({GetIt? getIt}) : getIt = getIt ?? GetIt.instance;

  /// Registers a lazy singleton factory for type [T].
  ///
  /// The [factoryFunc] closure is invoked **once** — on the first
  /// call to [get]`<T>()` — and the resulting instance is cached
  /// for the lifetime of this container.
  void registerLazySingleton<T extends Object>(
    T Function() factoryFunc, {
    String? instanceName,
  }) {
    getIt.registerLazySingleton<T>(factoryFunc, instanceName: instanceName);
  }

  /// Registers a factory for type [T].
  ///
  /// Unlike lazy singletons, [factoryFunc] is called on **every**
  /// invocation of [get]`<T>()`, producing a fresh instance each time.
  void registerFactory<T extends Object>(
    T Function() factoryFunc, {
    String? instanceName,
  }) {
    getIt.registerFactory<T>(factoryFunc, instanceName: instanceName);
  }

  /// Registers an eager singleton for type [T].
  ///
  /// The [factoryFunc] is invoked **immediately** during
  /// registration and the result is cached.
  void registerSingleton<T extends Object>(
    T Function() factoryFunc, {
    String? instanceName,
  }) {
    getIt.registerSingletonWithDependencies<T>(
      factoryFunc,
      instanceName: instanceName,
      dependsOn: null,
    );
  }

  /// Binds an already-instantiated [instance] as a singleton for type [T].
  ///
  /// This is the preferred registration method when writing tests
  /// that need to inject a mock or stub, or when manually wiring
  /// platform-specific objects obtained outside the DI container.
  void registerInstance<T extends Object>(
    T instance, {
    String? instanceName,
  }) {
    getIt.registerSingleton<T>(instance, instanceName: instanceName);
  }

  /// Retrieves the registered instance of type [T].
  ///
  /// Throws [StateError] if no registration exists for [T].
  T get<T extends Object>({String? instanceName}) {
    return getIt.get<T>(instanceName: instanceName);
  }

  /// Returns `true` if a registration for [T] exists.
  bool isRegistered<T extends Object>({String? instanceName}) {
    return getIt.isRegistered<T>(instanceName: instanceName);
  }

  /// Resets the container, clearing all registrations.
  ///
  /// Call this only during test teardown or full application
  /// re-initialisation.
  void reset() {
    getIt.reset();
  }
}
