import 'dart:convert';
import 'dart:io';

/// Static JSON registry index of plugins.
///
/// Format:
/// ```json
/// { "plugins": [ { "id":..., "name":..., "version":..., "description":..., "manifest": "<path or url>" } ] }
/// ```
class PluginRegistryIndex {
  final List<PluginRegistryEntry> plugins;

  const PluginRegistryIndex({this.plugins = const []});

  static PluginRegistryIndex load(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return const PluginRegistryIndex();
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) return const PluginRegistryIndex();
      final list = decoded['plugins'];
      if (list is! List) return const PluginRegistryIndex();
      return PluginRegistryIndex(
        plugins: list
            .whereType<Map<String, dynamic>>()
            .map(PluginRegistryEntry.fromJson)
            .toList(),
      );
    } catch (_) {
      return const PluginRegistryIndex();
    }
  }

  static PluginRegistryIndex fromJsonString(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return const PluginRegistryIndex();
      final list = decoded['plugins'];
      if (list is! List) return const PluginRegistryIndex();
      return PluginRegistryIndex(
        plugins: list
            .whereType<Map<String, dynamic>>()
            .map(PluginRegistryEntry.fromJson)
            .toList(),
      );
    } catch (_) {
      return const PluginRegistryIndex();
    }
  }
}

class PluginRegistryEntry {
  final String id;
  final String name;
  final String version;
  final String description;
  final String manifestPath;

  const PluginRegistryEntry({
    required this.id,
    this.name = '',
    this.version = '',
    this.description = '',
    this.manifestPath = '',
  });

  factory PluginRegistryEntry.fromJson(Map<String, dynamic> json) {
    return PluginRegistryEntry(
      id: (json['id'] ?? json['name'] ?? '').toString(),
      name: (json['name'] ?? json['id'] ?? '').toString(),
      version: (json['version'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      manifestPath:
          (json['manifest'] ?? json['manifest_path'] ?? json['path'] ?? '')
              .toString(),
    );
  }
}
