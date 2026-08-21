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
    // #348: `di` is bundled with the data presets so the canonical
    // `zfa make X --preset=crud` (or `--preset=read-only`) produces a
    // runnable app without the `--with=di` crutch. Every other preset
    // already includes di; crud/read-only were the only two that didn't,
    // and the resulting app compiled but crashed at runtime with
    // `GetIt: DataSource is not registered` (issue #346).
    'crud': ['usecase', 'repository', 'datasource', 'di'],
    'read-only': ['usecase', 'repository', 'datasource', 'di'],
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
