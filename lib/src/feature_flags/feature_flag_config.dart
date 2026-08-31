import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'feature_flag.dart';

export 'feature_flag.dart' show FeatureConfigException;

/// The `.zfa.json` file under [projectRoot] (or null when no root given).
File? configFileSync({String? projectRoot}) {
  final root = projectRoot ?? Directory.current.path;
  return File(p.join(root, '.zfa.json'));
}

/// Resolved, per-build feature-set: which features are enabled, which are
/// disabled, and the gates that apply at runtime. Produced by
/// [FeatureFlagConfig.resolve] and consumed by the generation pipeline
/// (route-stage filter, registry emitter, make skip hook).
class ResolvedFeatureSet {
  final Set<String> enabled;
  final Set<String> disabled;

  /// Gates per feature name (gates of enabled AND disabled features —
  /// disabled ones never resolve true, but the registry carries the full
  /// declaration so runtime providers can consult it).
  final Map<String, List<FeatureGate>> gates;

  const ResolvedFeatureSet({
    required this.enabled,
    required this.disabled,
    required this.gates,
  });

  bool isEnabled(String name) => enabled.contains(name);

  /// Sorted enabled names (stable emission order).
  List<String> get enabledList => enabled.toList()..sort();
}

/// Parsed + validated `features:`/`flavors:` configuration (spec 030
/// FR-001, FR-003). All validation failures throw [FeatureConfigException]
/// with a message naming the offending item.
class FeatureFlagConfig {
  final Map<String, FeatureFlag> flags;

  /// Flavor name -> { featureName: enabled } overrides.
  final Map<String, Map<String, bool>> flavors;

  const FeatureFlagConfig({required this.flags, this.flavors = const {}});

  List<String> get featureNames => flags.keys.toList()..sort();
  List<String> get flavorNames => flavors.keys.toList()..sort();
  FeatureFlag? flag(String name) => flags[name];
  Map<String, bool>? flavorOverrides(String flavor) => flavors[flavor];

  bool get isEmpty => flags.isEmpty;

  /// Parse from the raw `.zfa.json` map. Accepts two `features:` shapes:
  /// a list of `{ name, enabled, gates? }` objects (canonical) or a map
  /// `{ name: { enabled, gates? } }` (name implied by key).
  factory FeatureFlagConfig.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    final flags = <String, FeatureFlag>{};

    if (rawFeatures is List) {
      for (final entry in rawFeatures) {
        if (entry is! Map) {
          throw FeatureConfigException(
            'invalid features entry "$entry" — expected an object with '
            '"name" and "enabled"',
          );
        }
        final map = entry.cast<String, dynamic>();
        final flag = _parseFlagObject(map);
        if (flags.containsKey(flag.name)) {
          throw FeatureConfigException(
            'duplicate feature name "${flag.name}" in features section',
          );
        }
        flags[flag.name] = flag;
      }
    } else if (rawFeatures is Map) {
      for (final entry in rawFeatures.entries) {
        final name = entry.key.toString();
        final value = entry.value;
        if (value is bool) {
          flags[name] = FeatureFlag(name: name, enabled: value);
          continue;
        }
        if (value is! Map) {
          throw FeatureConfigException(
            'invalid features entry for "$name" — expected an object or '
            'boolean',
          );
        }
        final flag = _parseFlagObject(
          (value).cast<String, dynamic>(),
          impliedName: name,
        );
        if (flags.containsKey(flag.name)) {
          throw FeatureConfigException(
            'duplicate feature name "${flag.name}" in features section',
          );
        }
        flags[flag.name] = flag;
      }
    } else if (rawFeatures != null) {
      throw FeatureConfigException(
        'invalid "features" section — expected a list or a map',
      );
    }

    final rawFlavors = json['flavors'];
    final flavors = <String, Map<String, bool>>{};
    if (rawFlavors is Map) {
      for (final entry in rawFlavors.entries) {
        final flavorName = entry.key.toString();
        if (entry.value is! Map) {
          throw FeatureConfigException(
            'invalid flavor "$flavorName" — expected a map of '
            '"<featureName>": <bool>',
          );
        }
        final overrides = <String, bool>{};
        for (final ov in (entry.value as Map).entries) {
          final featureName = ov.key.toString();
          if (!flags.containsKey(featureName)) {
            throw FeatureConfigException(
              'flavor "$flavorName" overrides unknown feature '
              '"$featureName" — declare it in the features section first',
            );
          }
          if (ov.value is! bool) {
            throw FeatureConfigException(
              'flavor "$flavorName" override for "$featureName" must be a '
              'boolean',
            );
          }
          overrides[featureName] = ov.value as bool;
        }
        flavors[flavorName] = overrides;
      }
    } else if (rawFlavors != null) {
      throw FeatureConfigException(
        'invalid "flavors" section — expected a map',
      );
    }

    return FeatureFlagConfig(flags: flags, flavors: flavors);
  }

  static FeatureFlag _parseFlagObject(
    Map<String, dynamic> map, {
    String? impliedName,
  }) {
    final name = (map['name'] ?? impliedName)?.toString();
    if (name == null || name.isEmpty) {
      throw FeatureConfigException('features entry is missing a "name": $map');
    }
    if (!isValidFeatureName(name)) {
      throw FeatureConfigException(
        'invalid feature name "$name" — use alphanumeric characters and '
        'hyphens (e.g. "pro-analytics")',
      );
    }
    final enabled = map['enabled'];
    if (enabled is! bool) {
      throw FeatureConfigException(
        'feature "$name" is missing a boolean "enabled" state',
      );
    }
    final gates = <FeatureGate>[];
    final rawGates = map['gates'];
    if (rawGates is List) {
      for (final rawGate in rawGates) {
        final gateString = rawGate.toString();
        try {
          gates.add(FeatureGate.parse(gateString));
        } on FormatException catch (e) {
          throw FeatureConfigException(
            'feature "$name" declares an invalid gate: ${e.message}',
          );
        }
      }
    } else if (rawGates != null) {
      throw FeatureConfigException(
        'feature "$name" has an invalid "gates" section — expected a list '
        'of gate strings',
      );
    }
    return FeatureFlag(name: name, enabled: enabled, gates: gates);
  }

  /// Resolve the effective feature-set for [flavor] (null = base states).
  /// Unknown flavors throw naming the flavor.
  ResolvedFeatureSet resolve({String? flavor}) {
    if (flavor != null && !flavors.containsKey(flavor)) {
      throw FeatureConfigException(
        'unknown flavor "$flavor" — declared flavors: '
        '${flavorNames.isEmpty ? "(none)" : flavorNames.join(", ")}',
      );
    }
    final overrides = flavor == null ? null : flavors[flavor];
    final enabled = <String>{};
    final disabled = <String>{};
    final gates = <String, List<FeatureGate>>{};

    for (final flag in flags.values) {
      final effective = overrides?[flag.name] ?? flag.enabled;
      if (effective) {
        enabled.add(flag.name);
      } else {
        disabled.add(flag.name);
      }
      if (flag.gates.isNotEmpty) {
        gates[flag.name] = flag.gates;
      }
    }

    return ResolvedFeatureSet(
      enabled: enabled,
      disabled: disabled,
      gates: gates,
    );
  }

  /// Load from `.zfa.json` at [projectRoot] (defaults to cwd). Returns an
  /// empty config when no file or no features section exists.
  static FeatureFlagConfig load({String? projectRoot}) {
    final raw = loadRawJson(projectRoot: projectRoot);
    if (raw == null) return FeatureFlagConfig(flags: const {});
    return FeatureFlagConfig.fromJson(raw);
  }

  /// Raw `.zfa.json` map, or null when the file is absent. Throws
  /// [FeatureConfigException] on malformed JSON.
  static Map<String, dynamic>? loadRawJson({String? projectRoot}) {
    final file = configFileSync(projectRoot: projectRoot);
    if (file == null || !file.existsSync()) return null;
    try {
      final decoded = const JsonDecoder().convert(file.readAsStringSync());
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    } on FormatException catch (e) {
      throw FeatureConfigException(
        '${file.path} is not valid JSON: ${e.message}',
      );
    }
  }
}
