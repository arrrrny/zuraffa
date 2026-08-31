import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'feature_flag.dart';
import 'feature_flag_config.dart';

/// `zfa feature list|enable|disable <name>` service (spec 030 FR-002).
///
/// Reads and toggles the `features:` section of `.zfa.json` in place.
/// Handled failures print `❌ <message>` and set the dart:io `exitCode`
/// global (CliRunner._runDispatched honors it in real mode) — they never
/// call `exit()` so in-process test runs stay alive.
class FeatureFlagCli {
  /// Lists declared features. Text output is a simple aligned table;
  /// `--format=json` emits a JSON array. Empty config -> empty list, exit 0
  /// (US1.AC1).
  static bool list({String format = 'text', String? projectRoot}) {
    final FeatureFlagConfig config;
    try {
      final raw = FeatureFlagConfig.loadRawJson(projectRoot: projectRoot);
      config = raw == null
          ? FeatureFlagConfig(flags: const {})
          : FeatureFlagConfig.fromJson(raw);
    } on FeatureConfigException catch (e) {
      _fail(e.message);
      return false;
    }

    if (format == 'json') {
      final entries = config.featureNames
          .map(
            (name) => {
              'name': name,
              'enabled': config.flag(name)!.enabled,
              if (config.flag(name)!.gates.isNotEmpty)
                'gates': config
                    .flag(name)!
                    .gates
                    .map((g) => g.raw)
                    .toList(growable: false),
            },
          )
          .toList(growable: false);
      print(const JsonEncoder.withIndent('  ').convert(entries));
      return true;
    }

    if (config.isEmpty) {
      print('No features declared.');
      print(
        'Add a "features" section to .zfa.json or run '
        '`zfa feature enable <name>`.',
      );
      return true;
    }

    print('Features:');
    for (final name in config.featureNames) {
      final flag = config.flag(name)!;
      final state = flag.enabled ? 'enabled' : 'disabled';
      final gates = flag.gates.isEmpty
          ? ''
          : ' [gates: ${flag.gates.map((g) => g.raw).join(", ")}]';
      print('  $name: $state$gates');
    }
    return true;
  }

  /// Enables [name], declaring it if absent (upsert). Returns false on
  /// validation failure.
  static bool enable(String name, {String? projectRoot}) =>
      _setFlag(name, true, projectRoot: projectRoot);

  /// Disables [name]; an undeclared feature fails naming it (US1.AC3/AC4).
  static bool disable(String name, {String? projectRoot}) =>
      _setFlag(name, false, projectRoot: projectRoot);

  static bool _setFlag(String name, bool enabled, {String? projectRoot}) {
    if (!isValidFeatureName(name)) {
      _fail(
        'invalid feature name "$name" — use alphanumeric characters and '
        'hyphens (e.g. "pro-analytics")',
      );
      return false;
    }

    final Map<String, dynamic> raw;
    try {
      raw = FeatureFlagConfig.loadRawJson(projectRoot: projectRoot) ?? {};
      // Validate the original declaration before normalizing its shape. This
      // prevents unsupported values from being replaced with valid defaults.
      FeatureFlagConfig.fromJson(raw);
    } on FeatureConfigException catch (e) {
      _fail(e.message);
      return false;
    }

    final existed = raw['features'] != null;
    final List<dynamic> rawFeatures;
    if (raw['features'] is List) {
      rawFeatures = raw['features'] as List<dynamic>;
    } else if (raw['features'] is Map) {
      // normalize the map shape to the canonical list shape on write
      rawFeatures = (raw['features'] as Map).entries
          .map((entry) {
            final value = entry.value;
            if (value is bool) {
              return {'name': entry.key.toString(), 'enabled': value};
            }
            if (value is Map) {
              return {'name': entry.key.toString(), ...value};
            }
            return {'name': entry.key.toString(), 'enabled': true};
          })
          .toList(growable: true);
    } else {
      rawFeatures = <dynamic>[];
    }

    Map<String, dynamic>? existing;
    for (final entry in rawFeatures) {
      if (entry is Map && entry['name']?.toString() == name) {
        existing = entry.cast<String, dynamic>();
        break;
      }
    }

    if (existing == null && !enabled) {
      _fail(
        'feature "$name" is not declared in .zfa.json — declare it first '
        'with `zfa feature enable $name`',
      );
      return false;
    }

    if (existing != null) {
      existing['enabled'] = enabled;
    } else {
      rawFeatures.add({'name': name, 'enabled': enabled});
    }
    raw['features'] = rawFeatures;

    // Validate the resulting config before persisting (never write an
    // invalid config).
    try {
      FeatureFlagConfig.fromJson(raw);
    } on FeatureConfigException catch (e) {
      _fail(e.message);
      return false;
    }

    if (!existed && existing == null) {
      print(
        '✅ Declared and ${enabled ? "enabled" : "disabled"} feature: $name',
      );
    } else {
      print('✅ Feature $name is now ${enabled ? "enabled" : "disabled"}');
    }

    final configFile = File(
      p.join(projectRoot ?? Directory.current.path, '.zfa.json'),
    );
    const encoder = JsonEncoder.withIndent('  ');
    configFile.writeAsStringSync('${encoder.convert(raw)}\n');
    return true;
  }

  static void _fail(String message) {
    print('❌ $message');
    exitCode = 1;
  }
}
