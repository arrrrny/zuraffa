/// Feature-flag models and gate syntax (spec 030, issue #372).
///
/// A feature is declared in the `features:` section of `.zfa.json`:
/// `{ "name": "pro-analytics", "enabled": true, "gates": ["membership:pro"] }`.
/// Gates are colon-delimited conditions (`membership:<tier>`,
/// `locale:<l1>,<l2>`, `variant:<a|b>`, `custom:<name>`) evaluated at
/// runtime against injectable providers — see
/// `runtime/feature_flag_provider.dart`.
library;

/// Gate kinds supported by the feature-flag system.
enum FeatureGateType { membership, locale, variant, custom }

/// A single parsed gate condition attached to a feature.
final class FeatureGate {
  final FeatureGateType type;

  /// Raw value after the colon (for single-value gates).
  final String value;

  /// Split values (locale allow-list, variant list).
  final List<String> values;

  /// The original gate string, e.g. `locale:en-US,en-GB`.
  final String raw;

  const FeatureGate._(this.type, this.value, this.values, this.raw);

  /// Parse a gate string of the form `type:value`. Throws [FormatException]
  /// for malformed syntax (no colon, empty value).
  static FeatureGate parse(String rawGate) {
    final raw = rawGate.trim();
    final colon = raw.indexOf(':');
    if (colon <= 0) {
      throw FormatException(
        'invalid gate syntax "$rawGate" — expected "<type>:<value>"',
      );
    }
    final typePart = raw.substring(0, colon).trim().toLowerCase();
    final valuePart = raw.substring(colon + 1).trim();
    if (valuePart.isEmpty) {
      throw FormatException(
        'invalid gate syntax "$rawGate" — empty gate value',
      );
    }

    switch (typePart) {
      case 'membership':
        return FeatureGate._(FeatureGateType.membership, valuePart, [
          valuePart,
        ], raw);
      case 'locale':
        final locales = valuePart
            .split(',')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList(growable: false);
        if (locales.isEmpty) {
          throw FormatException(
            'invalid gate syntax "$rawGate" — empty locale list',
          );
        }
        return FeatureGate._(FeatureGateType.locale, valuePart, locales, raw);
      case 'variant':
        final variants = valuePart
            .split('|')
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toList(growable: false);
        if (variants.isEmpty) {
          throw FormatException(
            'invalid gate syntax "$rawGate" — empty variant list',
          );
        }
        return FeatureGate._(FeatureGateType.variant, valuePart, variants, raw);
      case 'custom':
        return FeatureGate._(FeatureGateType.custom, valuePart, [
          valuePart,
        ], raw);
      default:
        throw FormatException(
          'unknown gate type "$typePart" in gate "$rawGate" '
          '(supported: membership, locale, variant, custom)',
        );
    }
  }

  @override
  String toString() => raw;
}

/// A declared feature flag: name, build-time enabled state, optional gates.
final class FeatureFlag {
  final String name;
  final bool enabled;
  final List<FeatureGate> gates;

  const FeatureFlag({
    required this.name,
    required this.enabled,
    this.gates = const [],
  });

  /// `pro-analytics` -> `ProAnalytics` (the slice/class prefix this flag
  /// governs).
  String get pascalName => _kebabToPascal(name);

  /// `pro-analytics` -> `pro_analytics` (file-path segment form).
  String get snakeName => name.replaceAll('-', '_');

  static String _kebabToPascal(String name) => name
      .split('-')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join();

  Map<String, dynamic> toJson() => {
    'name': name,
    'enabled': enabled,
    if (gates.isNotEmpty) 'gates': gates.map((g) => g.raw).toList(),
  };
}

/// Valid feature name: alphanumeric plus hyphens (spec Assumption 2).
bool isValidFeatureName(String name) =>
    name.isNotEmpty && RegExp(r'^[a-zA-Z0-9]+(-[a-zA-Z0-9]+)*$').hasMatch(name);

/// `ProAnalytics` -> `pro-analytics` — maps a generated slice/entity name
/// onto its feature-flag name so the generation pipeline can match a
/// requested name against the disabled feature-set.
String pascalToKebab(String name) => name
    .replaceAllMapped(
      RegExp(r'([A-Z])'),
      (m) => '-${m.group(1)!.toLowerCase()}',
    )
    .replaceFirst(RegExp('^-'), '');

/// Validation/parse failure. The message always names the offending item
/// (feature, gate, or flavor) — US1.AC4 requires errors to name the
/// unknown feature.
class FeatureConfigException implements Exception {
  final String message;
  FeatureConfigException(this.message);

  @override
  String toString() => message;
}
