import '../../models/generator_config.dart';
import 'plugin_interface.dart';
import 'plugin_lifecycle.dart';

typedef ZuraffaPluginFactory = ZuraffaPlugin Function();

class PluginRegistry {
  final Map<String, ZuraffaPlugin> _plugins = {};

  List<ZuraffaPlugin> get plugins {
    final list = _plugins.values.toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return List.unmodifiable(list);
  }

  void register(ZuraffaPlugin plugin) {
    if (_plugins.containsKey(plugin.id)) {
      throw StateError('Plugin already registered: ${plugin.id}');
    }
    _plugins[plugin.id] = plugin;
  }

  void registerAll(Iterable<ZuraffaPlugin> plugins) {
    for (final plugin in plugins) {
      register(plugin);
    }
  }

  void discover(Iterable<ZuraffaPluginFactory> factories) {
    registerAll(factories.map((factory) => factory()));
  }

  ZuraffaPlugin? getById(String id) => _plugins[id];

  List<T> ofType<T extends ZuraffaPlugin>() {
    return plugins.whereType<T>().toList();
  }

  Future<ValidationResult> validateAll(GeneratorConfig config) async {
    var result = ValidationResult.success();
    for (final plugin in plugins) {
      final current = await plugin.validate(config);
      result = result.merge(current);
    }
    return result;
  }

  Future<void> beforeGenerateAll(GeneratorConfig config) async {
    for (final plugin in plugins) {
      await plugin.beforeGenerate(config);
    }
  }

  Future<void> afterGenerateAll(GeneratorConfig config) async {
    for (final plugin in plugins) {
      await plugin.afterGenerate(config);
    }
  }

  Future<void> onErrorAll(
    GeneratorConfig config,
    Object error,
    StackTrace stackTrace,
  ) async {
    for (final plugin in plugins) {
      await plugin.onError(config, error, stackTrace);
    }
  }
}
