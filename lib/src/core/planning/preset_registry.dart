class PresetRegistry {
  static const Map<String, List<String>> _presets = {
    'feature': [
      'usecase',
      'repository',
      'datasource',
      'view',
      'presenter',
      'controller',
      'state',
      'di',
      'test',
    ],
    'crud': ['usecase', 'repository', 'datasource'],
    'read-only': ['usecase', 'repository', 'datasource'],
    'service-feature': [
      'service',
      'provider',
      'usecase',
      'view',
      'presenter',
      'controller',
      'state',
      'di',
      'test',
    ],
    'adaptive-feature': [
      'usecase',
      'repository',
      'datasource',
      'view',
      'presenter',
      'controller',
      'state',
      'di',
      'test',
      'route',
    ],
    'platform-feature': [
      'usecase',
      'repository',
      'datasource',
      'view',
      'presenter',
      'controller',
      'state',
      'di',
      'test',
      'route',
    ],
  };

  const PresetRegistry._();

  static bool hasPreset(
    String name, {
    Map<String, List<String>>? customPresets,
  }) => _merged(customPresets).containsKey(name);

  static List<String> pluginIdsFor(
    String name, {
    Map<String, List<String>>? customPresets,
  }) => List<String>.from(_merged(customPresets)[name] ?? const <String>[]);

  static List<String> names({Map<String, List<String>>? customPresets}) =>
      _merged(customPresets).keys.toList(growable: false);

  static const Set<String> adaptivePresetNames = <String>{
    'adaptive-feature',
    'platform-feature',
  };

  static bool isAdaptivePreset(String? name) =>
      name != null && adaptivePresetNames.contains(name);

  static Map<String, List<String>> _merged(
    Map<String, List<String>>? customPresets,
  ) {
    if (customPresets == null || customPresets.isEmpty) {
      return _presets;
    }
    return {..._presets, ...customPresets};
  }
}
