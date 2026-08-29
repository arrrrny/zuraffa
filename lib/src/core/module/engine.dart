import 'dart:collection';

import 'di_container.dart';
import 'package_module.dart';
import '../../package/package_compatibility.dart';
import '../../version.dart';
import 'route_builder.dart';
import 'zuraffa_plugin.dart';

/// Central engine that discovers, wires, and initialises
/// [ZuraffaPlugin] instances.
///
/// The engine is the host application's single entry-point for
/// the micro-frontend plugin system. Typical usage:
///
/// ```dart
/// final engine = ZuraffaEngine();
///
/// engine
///   ..register(UserProfilePlugin())
///   ..register(CheckoutFlowPlugin())
///   ..register(AnalyticsPlugin());
///
/// await engine.bootstrap();
///
/// // Access the merged route table for the host router.
/// final allRoutes = engine.masterRouteMap;
/// ```
///
/// ## Bootstrap lifecycle
///
/// 1. **Register** -- call [register] for each plugin. Duplicate
///    [ZuraffaPlugin.pluginId] values throw [ArgumentError].
/// 2. **Bootstrap** -- call [bootstrap], which executes two
///    sub-phases in order:
///    a. **Dependency registration** -- every plugin's
///       [ZuraffaPlugin.registerDependencies] is called in
///       insertion order.
///    b. **Async initialisation** -- every plugin's
///       [ZuraffaPlugin.onInit] is called, also in insertion
///       order. Cross-plugin dependencies are now safe.
///
/// ## Fail-fast behaviour
///
/// - Duplicate [pluginId] throws [ArgumentError] at registration.
/// - Calling [register] after [bootstrap] throws [StateError].
/// - Calling [bootstrap] with zero plugins throws [StateError].
/// - Calling [bootstrap] more than once throws [StateError].
class ZuraffaEngine {
  /// Internal ordered map keyed by [ZuraffaPlugin.pluginId].
  final LinkedHashMap<String, ZuraffaPlugin> _plugins =
      LinkedHashMap<String, ZuraffaPlugin>();

  /// The shared DI container passed to all plugins during bootstrap.
  final ZuraffaDIContainer di;

  /// Whether [bootstrap] has been called.
  bool _bootstrapped = false;

  /// Whether [ready] has been called (spec 025).
  bool _readyCompleted = false;

  /// Whether [shutdown] has been called (spec 025).
  bool _shutdownCompleted = false;

  /// Creates an engine with an optional [ZuraffaDIContainer].
  ///
  /// If [di] is omitted, a fresh container wrapping
  /// [GetIt.instance] is created.
  ZuraffaEngine({ZuraffaDIContainer? di}) : di = di ?? ZuraffaDIContainer();

  /// Registers a [plugin] with this engine and returns `this`
  /// for fluent chaining.
  ///
  /// The plugin's [ZuraffaPlugin.pluginId] must be unique. If a
  /// plugin with the same ID is already registered, an
  /// [ArgumentError] is thrown.
  ///
  /// Must be called **before** [bootstrap].
  ZuraffaEngine register(ZuraffaPlugin plugin) {
    if (_bootstrapped) {
      throw StateError(
        'Cannot register plugin "${plugin.pluginId}" after '
        'bootstrap has completed.',
      );
    }

    final id = plugin.pluginId;
    if (id.isEmpty) {
      throw ArgumentError('ZuraffaPlugin.pluginId must not be empty.');
    }
    if (_plugins.containsKey(id)) {
      throw ArgumentError(
        'Duplicate plugin ID "$id". Each plugin must have a '
        'unique pluginId.',
      );
    }

    _plugins[id] = plugin;
    return this;
  }

  /// The ordered list of registered plugins.
  List<ZuraffaPlugin> get plugins =>
      UnmodifiableListView<ZuraffaPlugin>(_plugins.values.toList());

  /// Number of registered plugins.
  int get pluginCount => _plugins.length;

  /// Runs the two-phase bootstrap for all registered plugins.
  ///
  /// ### Phase 1 -- Dependency registration
  /// Each plugin's [ZuraffaPlugin.registerDependencies] is called
  /// in insertion order. Plugins should **only** register services.
  ///
  /// ### Phase 2 -- Async initialisation
  /// Each plugin's [ZuraffaPlugin.onInit] is awaited in insertion
  /// order. All dependencies from all plugins are now registered.
  Future<void> bootstrap() async {
    if (_bootstrapped) {
      throw StateError('bootstrap() has already been called.');
    }
    if (_plugins.isEmpty) {
      throw StateError(
        'Cannot bootstrap with zero registered plugins. '
        'Register at least one ZuraffaPlugin before calling bootstrap().',
      );
    }

    _bootstrapped = true;

    // Phase 1: register dependencies (sync, insertion order).
    for (final plugin in _plugins.values) {
      plugin.registerDependencies(di);
    }

    // Phase 2: async initialisation (insertion order).
    for (final plugin in _plugins.values) {
      await plugin.onInit(di);
    }
  }

  /// Merged route table from all registered plugins.
  ///
  /// Collects every [ZuraffaPlugin.routes] map and merges them
  /// into a single unmodifiable map. If multiple plugins define
  /// the same route key, the **last** registered plugin wins.
  Map<String, ZuraffaRouteHandler> get masterRouteMap {
    final merged = <String, ZuraffaRouteHandler>{};
    for (final plugin in _plugins.values) {
      merged.addAll(plugin.routes);
    }
    return Map.unmodifiable(merged);
  }

  /// Looks up a registered plugin by its [pluginId].
  ZuraffaPlugin? operator [](String pluginId) => _plugins[pluginId];

  /// Returns `true` if a plugin with [pluginId] has been registered.
  bool isRegistered(String pluginId) => _plugins.containsKey(pluginId);

  /// The discoverable identifiers of every registered module, in
  /// registration order (spec 025, FR-007).
  ///
  /// A consuming app queries this list to find activated package
  /// modules by their stable identifiers.
  List<String> get activeModuleIds => List.unmodifiable(_plugins.keys);

  /// Registers a [PackageModule] with a zuraffa compatibility gate
  /// (spec 025, FR-015).
  ///
  /// The module's declared [PackageModule.zuraffaSdkConstraint] is
  /// validated against the running zuraffa version before registration:
  /// a major-version mismatch throws [StateError] with a remediation
  /// message; a package built against a newer minor prints a warning and
  /// registers; otherwise the module registers like any plugin.
  ZuraffaEngine registerPackage(PackageModule module) {
    final result = PackageCompatibility.check(
      packageConstraint: module.zuraffaSdkConstraint,
      appVersion: version,
    );
    if (result.status == PackageCompatibilityStatus.incompatible) {
      throw StateError(
        'Package "${module.packageName}" is incompatible with this app: '
        '${result.message} — upgrade the app or the package before '
        'activating this module.',
      );
    }
    if (result.status == PackageCompatibilityStatus.warning) {
      print('⚠️  Package "${module.packageName}": ${result.message}');
    }
    return register(module);
  }

  /// Runs the readiness phase for all registered plugins (spec 025).
  ///
  /// Calls each plugin's [ZuraffaPlugin.onReady] in registration order,
  /// after [bootstrap] has completed. Calling [ready] before [bootstrap]
  /// or more than once throws [StateError].
  Future<void> ready() async {
    if (!_bootstrapped) {
      throw StateError('ready() requires bootstrap() to complete first.');
    }
    if (_readyCompleted) {
      throw StateError('ready() has already been called.');
    }

    _readyCompleted = true;

    for (final plugin in _plugins.values) {
      await plugin.onReady(di);
    }
  }

  /// Runs the disposal phase for all registered plugins (spec 025).
  ///
  /// Calls each plugin's [ZuraffaPlugin.onDispose] in **reverse**
  /// registration order so dependants tear down before their providers.
  /// Idempotent: a second call is a no-op, so shutdown paths can be
  /// defensive (e.g. `runZonedGuarded` finally blocks).
  Future<void> shutdown() async {
    if (_shutdownCompleted) return;
    _shutdownCompleted = true;

    final plugins = _plugins.values.toList();
    for (final plugin in plugins.reversed) {
      await plugin.onDispose(di);
    }
  }
}
