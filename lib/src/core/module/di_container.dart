import 'package:get_it/get_it.dart';

import 'interceptor.dart';

/// A lightweight dependency-injection container that wraps [GetIt].
///
/// [ZuraffaDIContainer] provides a thin, typed facade over [GetIt] so
/// that generated DI setup code and micro-frontend plugins can exchange
/// service registrations through a stable contract that does not leak
/// the full [GetIt] API surface.
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
/// ## Override behaviour
///
/// When [override] is `true` (default `false`), any existing registration
/// for type [T] is unregistered before the new one is registered. This
/// allows plugins to replace core bindings:
///
/// ```dart
/// // Core registration
/// await di.registerLazySingleton<PaymentGateway>(() => StripeGateway());
///
/// // Plugin override
/// await di.registerLazySingleton<PaymentGateway>(
///   () => MockPaymentGateway(),
///   override: true,
/// );
/// ```
///
/// When [override] is `false` and a binding already exists, registration
/// throws a [StateError] naming the conflicting type `T`.
///
/// ## Interceptor registration
///
/// The container also hosts an [interceptorRegistry] for UseCase
/// interceptor chains. Use [registerInterceptor] to add interceptors.
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
/// await di.registerLazySingleton<MyService>(() => MyServiceImpl());
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

  /// Registry for UseCase interceptor chains.
  ///
  /// Interceptors registered here are consulted by
  /// [InterceptableUseCase] subclasses during execution.
  final InterceptorRegistry interceptorRegistry;

  /// Creates a new [ZuraffaDIContainer] wrapping [getIt].
  ///
  /// If [getIt] is `null`, [GetIt.instance` is used. Supplying an
  /// explicit instance is recommended in tests so that each test
  /// gets an isolated container:
  ///
  /// ```dart
  /// final di = ZuraffaDIContainer(getIt: GetIt.asNewInstance());
  /// ```
  ZuraffaDIContainer({GetIt? getIt, InterceptorRegistry? interceptorRegistry})
    : getIt = getIt ?? GetIt.instance,
      interceptorRegistry = interceptorRegistry ?? InterceptorRegistry();

  /// Registers a lazy singleton factory for type [T].
  ///
  /// The [factoryFunc] closure is invoked **once** -- on the first
  /// call to [get]`<T>()` -- and the resulting instance is cached
  /// for the lifetime of this container.
  ///
  /// When [override] is `true`, any existing registration for [T] is
  /// replaced. When `false` (default) and [T] is already registered,
  /// throws [StateError].
  Future<void> registerLazySingleton<T extends Object>(
    T Function() factoryFunc, {
    String? instanceName,
    bool override = false,
  }) async {
    _checkOverride<T>(override, instanceName);
    if (override && getIt.isRegistered<T>(instanceName: instanceName)) {
      await getIt.unregister<T>(instanceName: instanceName);
    }
    getIt.registerLazySingleton<T>(factoryFunc, instanceName: instanceName);
  }

  /// Registers a factory for type [T].
  ///
  /// Unlike lazy singletons, [factoryFunc] is called on **every**
  /// invocation of [get]`<T>()`, producing a fresh instance each time.
  ///
  /// When [override] is `true`, any existing registration for [T] is
  /// replaced. When `false` (default) and [T] is already registered,
  /// throws [StateError].
  Future<void> registerFactory<T extends Object>(
    T Function() factoryFunc, {
    String? instanceName,
    bool override = false,
  }) async {
    _checkOverride<T>(override, instanceName);
    if (override && getIt.isRegistered<T>(instanceName: instanceName)) {
      await getIt.unregister<T>(instanceName: instanceName);
    }
    getIt.registerFactory<T>(factoryFunc, instanceName: instanceName);
  }

  /// Registers an eager singleton for type [T].
  ///
  /// The [factoryFunc] is invoked **immediately** during
  /// registration and the result is cached.
  ///
  /// When [override] is `true`, any existing registration for [T] is
  /// replaced. When `false` (default) and [T] is already registered,
  /// throws [StateError].
  Future<void> registerSingleton<T extends Object>(
    T Function() factoryFunc, {
    String? instanceName,
    bool override = false,
  }) async {
    _checkOverride<T>(override, instanceName);
    if (override && getIt.isRegistered<T>(instanceName: instanceName)) {
      await getIt.unregister<T>(instanceName: instanceName);
    }
    // Eagerly invoke the factory and register the resulting instance.
    // This avoids registerSingletonWithDependencies which can leave stale
    // internal state after unregister+re-register cycles.
    final instance = factoryFunc();
    getIt.registerSingleton<T>(instance, instanceName: instanceName);
  }

  /// Binds an already-instantiated [instance] as a singleton for type [T].
  ///
  /// This is the preferred registration method when writing tests
  /// that need to inject a mock or stub, or when manually wiring
  /// platform-specific objects obtained outside the DI container.
  ///
  /// When [override] is `true`, any existing registration for [T] is
  /// replaced. When `false` (default) and [T] is already registered,
  /// throws [StateError].
  Future<void> registerInstance<T extends Object>(
    T instance, {
    String? instanceName,
    bool override = false,
  }) async {
    _checkOverride<T>(override, instanceName);
    if (override && getIt.isRegistered<T>(instanceName: instanceName)) {
      await getIt.unregister<T>(instanceName: instanceName);
    }
    getIt.registerSingleton<T>(instance, instanceName: instanceName);
  }

  /// Registers an interceptor for UseCase input type [In] and output
  /// type [Out].
  ///
  /// The interceptor is added to the [interceptorRegistry] and will
  /// be consulted by any [InterceptableUseCase] that shares this
  /// container's registry.
  ///
  /// Multiple interceptors for the same `[In, Out]` pair run in
  /// registration order (first registered = outermost in the chain).
  void registerInterceptor<In, Out>(InterceptorEntry<In, Out> entry) {
    interceptorRegistry.register<In, Out>(entry);
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

  /// Resets the container, clearing all registrations and interceptors.
  ///
  /// Call this only during test teardown or full application
  /// re-initialisation.
  Future<void> reset() async {
    interceptorRegistry.clear();
    await getIt.reset();
  }

  /// Throws [StateError] when [override] is false and [T] is already
  /// registered.
  void _checkOverride<T extends Object>(bool override, String? instanceName) {
    if (!override && getIt.isRegistered<T>(instanceName: instanceName)) {
      throw StateError(
        'A registration for $T already exists. '
        'Use override: true to replace it, or unregister it first.',
      );
    }
  }
}
