/// FeatureId (spec 1115, issue #1115): the TYPED feature identifier.
///
/// Before 1115 the feature identity traveled as a raw, unvalidated
/// `String` through xray (`XRayNode.featureId`), the audit bus and the
/// capability arguments — the same class of bug spec 1098 removed from the
/// contract itself. A [FeatureId] is parsed ONCE (validating the
/// kebab/numeric-segment shape contracts declare, e.g. `004-login-ui`)
/// and compared by value, so a malformed or wrong feature cannot ride the
/// wire through slice + xray + auditor + receipt.
library;

/// A validated feature contract id.
class FeatureId {
  /// Contract ids are kebab-case with optional numeric prefixes
  /// (`login`, `004-login-ui`).
  static final RegExp _pattern = RegExp(r'^[a-z0-9][a-z0-9_-]*$');

  /// The validated id value.
  final String value;

  const FeatureId._(this.value);

  /// Parses [raw] into a [FeatureId].
  ///
  /// Throws [ArgumentError] for an empty, unnormalized or path-bearing
  /// value — an unvalidated id is exactly what this type exists to stop.
  factory FeatureId.parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(raw, 'raw', 'FeatureId must not be empty');
    }
    if (!_pattern.hasMatch(value)) {
      throw ArgumentError.value(
        raw,
        'raw',
        'FeatureId must be kebab-case '
            '(lowercase letters, digits, "-" or "_"), e.g. "004-login-ui"',
      );
    }
    return FeatureId._(value);
  }

  /// Like [FeatureId.parse] but returns `null` instead of throwing —
  /// for read sites that must tolerate legacy/corrupt input.
  static FeatureId? tryParse(String raw) {
    try {
      return FeatureId.parse(raw);
    } on ArgumentError {
      return null;
    }
  }

  @override
  bool operator ==(Object other) => other is FeatureId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
