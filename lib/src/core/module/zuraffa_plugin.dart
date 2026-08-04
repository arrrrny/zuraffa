import 'di_container.dart';
import 'route_builder.dart';

/// Abstract contract that every Zuraffa micro-frontend plugin must
/// implement.
///
/// A [ZuraffaPlugin] declares four capabilities that the host
/// application consumes through the [ZuraffaEngine]:
///
/// 1. **Identity** -- [pluginId] uniquely identifies the plugin
///    within the engine. Duplicates are rejected at registration
///    time.
/// 2. **Dependency registration** -- [registerDependencies] is
///    called during the engine's bootstrap phase so the plugin
///    can register its services into the shared [ZuraffaDIContainer].
/// 3. **Route contribution** -- [routes] returns the map of route
///    names to [ZuraffaRouteBuilder] functions.
/// 4. **Async initialisation** -- [onInit] runs after all plugins
///    have registered their dependencies, giving each plugin a
///    chance to perform async work before the app becomes interactive.
///
/// ## Lifecycle
///
/// The engine orchestrates plugins through two phases:
///
/// 1. **Registration phase** -- [registerDependencies] is called for
///    every plugin in insertion order. Only registrations.
/// 2. **Init phase** -- [onInit] is called for every plugin. All
///    dependencies from all plugins are now available.
///
/// ## Example
///
/// ```dart
/// class UserProfilePlugin extends ZuraffaPlugin {
///   @override
///   String get pluginId => 'user_profile';
///
///   @override
///   void registerDependencies(ZuraffaDIContainer di) {
///     di.registerLazySingleton<UserRepository>(() => UserRepositoryImpl());
///     di.registerFactory<ProfileBloc>(() => ProfileBloc(di.get()));
///   }
///
///   @override
///   Map<String, ZuraffaRouteBuilder> get routes => {
///     '/profile': (context, args) => ProfilePage(),
///     '/profile/edit': (context, args) => ProfileEditPage(),
///   };
///
///   @override
///   Future<void> onInit(ZuraffaDIContainer di) async {
///     final repo = di.get<UserRepository>();
///     await repo.warmCache();
///   }
/// }
/// ```
abstract class ZuraffaPlugin {
  /// Unique identifier for this plugin.
  ///
  /// Must be non-empty and unique across all plugins registered
  /// with the same [ZuraffaEngine]. A runtime [ArgumentError] is
  /// thrown if a duplicate [pluginId] is encountered.
  ///
  /// Convention: use `snake_case` strings (e.g. `'user_profile'`).
  String get pluginId;

  /// Registers this plugin's dependencies into the shared [di]
  /// container.
  ///
  /// Called during the engine's bootstrap phase, **before**
  /// any [onInit] calls. Only registration methods should be
  /// invoked here; do **not** call [ZuraffaDIContainer.get]
  /// because other plugins' dependencies may not yet be registered.
  void registerDependencies(ZuraffaDIContainer di);

  /// Route table contributed by this plugin.
  ///
  /// Each key is a route name (e.g. `'/profile'`) and each value
  /// is a [ZuraffaRouteBuilder] that produces the page widget.
  ///
  /// The engine collects all routes from all plugins and merges
  /// them into the host application's routing table.
  Map<String, ZuraffaRouteBuilder> get routes;

  /// Asynchronous initialisation hook called after **all** plugins
  /// have completed [registerDependencies].
  ///
  /// The default implementation is a no-op. Override when
  /// async work is needed (cache warming, API prefetching, etc.).
  Future<void> onInit(ZuraffaDIContainer di) async {}
}
