import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/file_utils.dart';

/// Unified v5 configuration for Zuraffa.
class ZfaConfig {
  static const String fixedDomainRoot = 'lib/src/domain';
  static const String fixedEntityOutput = '$fixedDomainRoot/entities';
  static const List<String> defaultAdaptiveLayoutTargets = <String>[
    'mobile',
    'tablet',
    'desktop',
    'macos',
  ];

  static const Map<String, bool> _builtinPluginDefaults = {
    'repository': false,
    'provider': false,
    'usecase': false,
    'presenter': false,
    'controller': false,
    'view': false,
    'feature': false,
    'state': false,
    'observer': false,
    'test': false,
    'mock': false,
    'di': false,
    'datasource': false,
    'service': false,
    'route': false,
    'cache': false,
    'gql': false,
    'graphql': false,
    'shadcn': false,
    'method_append': false,
  };

  final Map<String, bool> pluginDefaults;
  final Set<String> disabledPlugins;
  final Map<String, List<String>> customPresets;
  final Map<String, List<String>> customAliases;
  final Map<String, dynamic> uiDefaults;
  final bool jsonByDefault;
  final bool compareByDefault;
  final bool filterByDefault;
  final bool buildByDefault;
  final bool formatByDefault;
  final bool entityFirst;
  final bool zorphyOnly;
  final String domainRoot;

  ZfaConfig({
    Map<String, bool>? pluginDefaults,
    Set<String>? disabledPlugins,
    Map<String, List<String>>? customPresets,
    Map<String, List<String>>? customAliases,
    Map<String, dynamic>? uiDefaults,
    this.jsonByDefault = true,
    this.compareByDefault = true,
    this.filterByDefault = false,
    this.buildByDefault = false,
    this.formatByDefault = false,
    this.entityFirst = true,
    this.zorphyOnly = true,
    this.domainRoot = fixedDomainRoot,
    bool? diByDefault,
    bool? routeByDefault,
    bool? mockByDefault,
    bool? testByDefault,
    bool? gqlByDefault,
    bool? graphqlByDefault,
    bool? appendByDefault,
    bool? cacheByDefault,
  }) : pluginDefaults = Map.unmodifiable({
         ..._builtinPluginDefaults,
         ...?pluginDefaults,
         ..._namedDefaultOverrides(
           diByDefault: diByDefault,
           routeByDefault: routeByDefault,
           mockByDefault: mockByDefault,
           testByDefault: testByDefault,
           gqlByDefault: gqlByDefault,
           graphqlByDefault: graphqlByDefault,
           appendByDefault: appendByDefault,
           cacheByDefault: cacheByDefault,
         ),
       }),
       disabledPlugins = Set.unmodifiable(disabledPlugins ?? const <String>{}),
       customPresets = Map.unmodifiable(_normalizeNamedLists(customPresets)),
       customAliases = Map.unmodifiable(_normalizeNamedLists(customAliases)),
       uiDefaults = Map.unmodifiable(uiDefaults ?? const <String, dynamic>{});

  bool get diByDefault => isPluginEnabledByDefault('di');
  bool get routeByDefault => isPluginEnabledByDefault('route');
  bool get mockByDefault => isPluginEnabledByDefault('mock');
  bool get testByDefault => isPluginEnabledByDefault('test');
  bool get gqlByDefault => isPluginEnabledByDefault('gql');
  bool get graphqlByDefault => isPluginEnabledByDefault('graphql');
  bool get appendByDefault => isPluginEnabledByDefault('method_append');
  bool get cacheByDefault => isPluginEnabledByDefault('cache');
  bool get adaptiveLayoutsByDefault =>
      uiDefaults['adaptiveLayouts'] == true ||
      uiDefaults['adaptive_layouts'] == true;
  bool get platformShellsByDefault =>
      uiDefaults['platformShells'] == true ||
      uiDefaults['platform_shells'] == true;
  List<String> get adaptiveLayoutTargets {
    final raw =
        uiDefaults['layoutTargets'] ??
        uiDefaults['layout_targets'] ??
        uiDefaults['adaptiveLayoutTargets'];
    if (raw is List) {
      final values = raw
          .map((item) => item.toString().trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (values.isNotEmpty) {
        return values;
      }
    }
    return defaultAdaptiveLayoutTargets;
  }

  String get adaptivePreset =>
      (uiDefaults['adaptivePreset'] ?? uiDefaults['adaptive_preset'])
          ?.toString() ??
      'adaptive-feature';

  // Backward-compatible accessors while the rest of the codebase migrates.
  bool get zorphyByDefault => true;
  String get defaultEntityOutput => fixedEntityOutput;

  bool isPluginEnabledByDefault(String pluginId) =>
      pluginDefaults[pluginId] ?? false;

  ZfaConfig copyWith({
    Map<String, bool>? pluginDefaults,
    Set<String>? disabledPlugins,
    Map<String, List<String>>? customPresets,
    Map<String, List<String>>? customAliases,
    Map<String, dynamic>? uiDefaults,
    bool? jsonByDefault,
    bool? compareByDefault,
    bool? filterByDefault,
    bool? buildByDefault,
    bool? formatByDefault,
    bool? entityFirst,
    bool? zorphyOnly,
    String? domainRoot,
  }) {
    return ZfaConfig(
      pluginDefaults: pluginDefaults ?? this.pluginDefaults,
      disabledPlugins: disabledPlugins ?? this.disabledPlugins,
      customPresets: customPresets ?? this.customPresets,
      customAliases: customAliases ?? this.customAliases,
      uiDefaults: uiDefaults ?? this.uiDefaults,
      jsonByDefault: jsonByDefault ?? this.jsonByDefault,
      compareByDefault: compareByDefault ?? this.compareByDefault,
      filterByDefault: filterByDefault ?? this.filterByDefault,
      buildByDefault: buildByDefault ?? this.buildByDefault,
      formatByDefault: formatByDefault ?? this.formatByDefault,
      entityFirst: entityFirst ?? this.entityFirst,
      zorphyOnly: zorphyOnly ?? this.zorphyOnly,
      domainRoot: domainRoot ?? this.domainRoot,
    );
  }

  static String configKeyForPlugin(String pluginId) {
    const overrides = {
      'method_append': 'appendByDefault',
      'gql': 'gqlByDefault',
      'graphql': 'graphqlByDefault',
    };
    return overrides[pluginId] ?? '${pluginId}ByDefault';
  }

  static String? pluginIdForConfigKey(String key) {
    const explicit = {
      'appendByDefault': 'method_append',
      'gqlByDefault': 'gql',
      'graphqlByDefault': 'graphql',
    };
    final explicitMatch = explicit[key];
    if (explicitMatch != null) {
      return explicitMatch;
    }
    if (!key.endsWith('ByDefault')) {
      return null;
    }
    final prefix = key.substring(0, key.length - 'ByDefault'.length);
    if (prefix.isEmpty) {
      return null;
    }
    return '${prefix[0].toLowerCase()}${prefix.substring(1)}';
  }

  static ZfaConfig? load({String? projectRoot}) {
    final root = projectRoot ?? Directory.current.path;
    final configFile = File(p.join(root, '.zfa.json'));

    if (!configFile.existsSync()) {
      return null;
    }

    try {
      final content = configFile.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return ZfaConfig.fromJson(json);
    } catch (_) {
      return ZfaConfig();
    }
  }

  factory ZfaConfig.fromJson(Map<String, dynamic> json) {
    final plugins = _map(json['plugins']);
    final planning = _map(json['planning']);
    final entity = _map(json['entity']);
    final defaults = <String, bool>{
      ..._legacyPluginDefaults(json),
      ..._boolMap(plugins['defaults']),
    };

    return ZfaConfig(
      pluginDefaults: defaults,
      disabledPlugins: _stringSet(
        plugins['disabled'] ?? json['disabledPlugins'],
      ),
      customPresets: _normalizeNamedLists(
        _listMap(planning['presets'] ?? json['presets']),
      ),
      customAliases: _normalizeNamedLists(
        _listMap(planning['aliases'] ?? json['aliases']),
      ),
      uiDefaults: _map(json['ui']),
      jsonByDefault:
          (entity['jsonByDefault'] ?? json['jsonByDefault']) != false,
      compareByDefault:
          (entity['compareByDefault'] ?? json['compareByDefault']) != false,
      filterByDefault:
          entity['filterByDefault'] == true || json['filterByDefault'] == true,
      buildByDefault: json['buildByDefault'] == true,
      formatByDefault: json['formatByDefault'] == true,
      entityFirst: entity['entityFirst'] != false,
      zorphyOnly: true,
      domainRoot: fixedDomainRoot,
    );
  }

  static Future<void> save(ZfaConfig config, {String? projectRoot}) async {
    final root = projectRoot ?? Directory.current.path;
    final configFile = File(p.join(root, '.zfa.json'));

    const encoder = JsonEncoder.withIndent('  ');
    final content = encoder.convert(config.toJson());
    await FileUtils.writeFile(configFile.path, content, 'config', force: true);
  }

  Map<String, dynamic> toJson() => {
    'plugins': {
      'defaults': _sortedBoolMap(pluginDefaults),
      'disabled': disabledPlugins.toList()..sort(),
    },
    'planning': {
      'presets': _sortedListMap(customPresets),
      'aliases': _sortedListMap(customAliases),
    },
    'ui': {
      ...uiDefaults,
      'adaptiveLayouts': adaptiveLayoutsByDefault,
      'platformShells': platformShellsByDefault,
      'layoutTargets': adaptiveLayoutTargets,
      'adaptivePreset': adaptivePreset,
    },
    'entity': {
      'entityFirst': entityFirst,
      'jsonByDefault': jsonByDefault,
      'compareByDefault': compareByDefault,
      'filterByDefault': filterByDefault,
    },
    'buildByDefault': buildByDefault,
    'formatByDefault': formatByDefault,
  };

  static Future<void> init({String? projectRoot}) async {
    final root = projectRoot ?? Directory.current.path;
    final configFile = File(p.join(root, '.zfa.json'));

    if (configFile.existsSync()) {
      print('ℹ️  Configuration file already exists: ${configFile.path}');
      return;
    }

    await save(ZfaConfig(), projectRoot: root);
    print('✅ Created configuration file: ${configFile.path}');
    print('   Canonical generation defaults now live under plugins.defaults.');
    print(
      '   v5 uses fixed generation paths under lib/src/domain and lib/src/domain/entities.',
    );
    print(
      '   Adaptive layout scaffolding can be enabled under ui.adaptiveLayouts with targets from ui.layoutTargets.',
    );
  }

  static Map<String, bool> _namedDefaultOverrides({
    bool? diByDefault,
    bool? routeByDefault,
    bool? mockByDefault,
    bool? testByDefault,
    bool? gqlByDefault,
    bool? graphqlByDefault,
    bool? appendByDefault,
    bool? cacheByDefault,
  }) {
    final overrides = <String, bool>{};
    if (diByDefault case final value?) overrides['di'] = value;
    if (routeByDefault case final value?) overrides['route'] = value;
    if (mockByDefault case final value?) overrides['mock'] = value;
    if (testByDefault case final value?) overrides['test'] = value;
    if (gqlByDefault case final value?) overrides['gql'] = value;
    if (graphqlByDefault case final value?) overrides['graphql'] = value;
    if (appendByDefault case final value?) {
      overrides['method_append'] = value;
    }
    if (cacheByDefault case final value?) overrides['cache'] = value;
    return overrides;
  }

  static Map<String, bool> _legacyPluginDefaults(Map<String, dynamic> json) {
    final defaults = <String, bool>{};
    for (final entry in json.entries) {
      final pluginId = pluginIdForConfigKey(entry.key);
      if (pluginId != null && entry.value is bool) {
        defaults[pluginId] = entry.value as bool;
      }
    }
    return defaults;
  }

  static Map<String, bool> _boolMap(dynamic value) {
    if (value is! Map) return const {};
    return value.map(
      (key, dynamic rawValue) => MapEntry(key.toString(), rawValue == true),
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, dynamic rawValue) => MapEntry(key.toString(), rawValue),
      );
    }
    return const <String, dynamic>{};
  }

  static Map<String, List<String>> _listMap(dynamic value) {
    if (value is! Map) return const {};
    return value.map((key, dynamic rawValue) {
      final items = rawValue is List
          ? rawValue.map((item) => item.toString()).toList(growable: false)
          : <String>[];
      return MapEntry(key.toString(), items);
    });
  }

  static Map<String, List<String>> _normalizeNamedLists(
    Map<String, List<String>>? value,
  ) {
    if (value == null) return const {};
    final normalized = <String, List<String>>{};
    for (final entry in value.entries) {
      normalized[entry.key] = entry.value
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return normalized;
  }

  static Set<String> _stringSet(dynamic value) {
    if (value is! List) return const {};
    return value.map((item) => item.toString()).toSet();
  }

  static Map<String, bool> _sortedBoolMap(Map<String, bool> value) {
    final keys = value.keys.toList()..sort();
    return {for (final key in keys) key: value[key] ?? false};
  }

  static Map<String, List<String>> _sortedListMap(
    Map<String, List<String>> value,
  ) {
    final keys = value.keys.toList()..sort();
    return {for (final key in keys) key: value[key] ?? const <String>[]};
  }
}
