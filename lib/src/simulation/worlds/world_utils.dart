/// Shared utilities for simulation worlds (spec 968).
///
/// Extracted from world_runtime, world_manifest, and world_certification
/// to eliminate duplicate `_shapeOf`, `_canonical`, and `_pow` helpers.
library;

/// Returns a machine-readable shape label for [value].
String shapeOf(dynamic value) => switch (value) {
  null => 'void',
  Map => 'map',
  List => 'list',
  String => 'string',
  num || bool => 'scalar',
  _ => 'value',
};

/// Canonicalizes [value] for deterministic JSON serialization: sorted map
/// keys, recursive descent into nested maps and lists.
dynamic canonical(dynamic value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: canonical(value[k])};
  }
  if (value is List) return [for (final e in value) canonical(e)];
  return value;
}

/// Integer exponentiation without `dart:math`.
int powInt(double base, int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= base;
  }
  return result.round();
}
