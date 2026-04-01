import 'plugin_interface.dart';
import 'plugin_lifecycle.dart';
import 'plugin_context.dart';

typedef ZuraffaPluginFactory = ZuraffaPlugin Function();

/// Registry for managing the lifecycle of generation plugins.
///
/// Handles plugin registration, discovery, and execution of lifecycle
/// hooks (validate, beforeGenerate, afterGenerate, onError).
class PluginRegistry {
  static final PluginRegistry instance = PluginRegistry();
  final Map<String, ZuraffaPlugin> _plugins = {};

  /// Returns all registered plugins.
  List<ZuraffaPlugin> get plugins => List.unmodifiable(_plugins.values);

  /// Sorts a list of plugins according to their dependencies and [runAfter] rules.
  List<ZuraffaPlugin> sortPlugins(Iterable<ZuraffaPlugin> targets) {
    final sorted = <ZuraffaPlugin>[];
    final visited = <String>{};
    final visiting = <String>{};

    void visit(ZuraffaPlugin plugin) {
      if (visited.contains(plugin.id)) return;
      if (visiting.contains(plugin.id)) {
        throw StateError('Circular dependency detected: ${plugin.id}');
      }

      visiting.add(plugin.id);

      // Visit dependencies
      for (final depId in [...plugin.dependsOn, ...plugin.runAfter]) {
        final dep = _plugins[depId];
        // Only visit if the dependency is also in our target set
        if (dep != null && targets.any((t) => t.id == depId)) {
          visit(dep);
        }
      }

      visiting.remove(plugin.id);
      visited.add(plugin.id);
      sorted.add(plugin);
    }

    for (final plugin in targets) {
      visit(plugin);
    }

    return sorted;
  }

  /// Registers a new plugin.
  void register(ZuraffaPlugin plugin) {
    if (_plugins.containsKey(plugin.id)) {
      throw StateError('Plugin already registered: ${plugin.id}');
    }
    _plugins[plugin.id] = plugin;
  }

  /// Registers multiple plugins.
  void registerAll(Iterable<ZuraffaPlugin> plugins) {
    for (final plugin in plugins) {
      register(plugin);
    }
  }

  /// Discovers plugins via factory functions.
  void discover(Iterable<ZuraffaPluginFactory> factories) {
    registerAll(factories.map((factory) => factory()));
  }

  /// Gets a plugin by its unique ID.
  ZuraffaPlugin? getById(String id) => _plugins[id];

  /// Filters plugins by type.
  List<T> ofType<T extends ZuraffaPlugin>() {
    return plugins.whereType<T>().toList();
  }

  /// Validates all registered plugins against the [context].
  Future<ValidationResult> validateAll(PluginContext context) async {
    var result = ValidationResult.success();
    for (final plugin in plugins) {
      final current = await plugin.validate(context);
      result = result.merge(current);
    }
    return result;
  }

  /// Executes [beforeGenerate] for all registered plugins.
  Future<void> beforeGenerateAll(PluginContext context) async {
    for (final plugin in plugins) {
      await plugin.beforeGenerate(context);
    }
  }

  /// Executes [afterGenerate] for all registered plugins.
  Future<void> afterGenerateAll(PluginContext context) async {
    for (final plugin in plugins) {
      await plugin.afterGenerate(context);
    }
  }

  /// Executes [onError] for all registered plugins.
  Future<void> onErrorAll(
    PluginContext context,
    Object error,
    StackTrace stackTrace,
  ) async {
    for (final plugin in plugins) {
      await plugin.onError(context, error, stackTrace);
    }
  }
}
