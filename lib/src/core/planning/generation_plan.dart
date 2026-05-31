import '../plugin_system/plugin_interface.dart';

/// Normalized execution contract resolved before generation runs.
class GenerationPlan {
  final String name;
  final String? preset;
  final List<String> requestedPluginIds;
  final List<String> pluginIds;
  final List<ZuraffaPlugin> activePlugins;
  final List<String> warnings;
  final Map<String, dynamic> normalizedOptions;

  const GenerationPlan({
    required this.name,
    required this.preset,
    required this.requestedPluginIds,
    required this.pluginIds,
    required this.activePlugins,
    required this.warnings,
    required this.normalizedOptions,
  });

  List<String> get executionOrder =>
      activePlugins.map((plugin) => plugin.id).toList(growable: false);

  Map<String, dynamic> toJson() => {
    'name': name,
    if (preset != null) 'preset': preset,
    'requested_plugin_ids': requestedPluginIds,
    'plugin_ids': pluginIds,
    'execution_order': executionOrder,
    'warnings': warnings,
    'normalized_options': normalizedOptions,
  };
}
