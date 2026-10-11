/// XRayLayer (spec 1098): the deck layer a feature contract is assigned to.
///
/// The xray deck knows file→layer; the typed FeatureContract carries the
/// layer assignment as a first-class enum so `zfa xray deck --feature <id>`
/// groups nodes by contract id AND layer without re-deriving either from
/// path conventions.
library;

/// Clean-architecture layer assignment for a feature's xray deck group.
enum XRayLayer {
  /// Widgets, views, presenters, controllers (`lib/src/presentation/**`).
  presentation,

  /// Use cases, entities, repository interfaces (`lib/src/domain/**`).
  domain,

  /// Datasources, mock data, DI wiring of concrete implementations
  /// (`lib/src/data/**`).
  data;

  /// Parses a `--xray-layer` / `xray_layer:` contract value.
  ///
  /// Throws [ArgumentError] for unknown values — an unvalidated layer
  /// string is exactly the class of bug spec 1098 removes.
  static XRayLayer parse(String value) {
    final normalized = value.trim().toLowerCase();
    for (final layer in XRayLayer.values) {
      if (layer.name == normalized) return layer;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Unknown xray layer (expected one of: '
          '${XRayLayer.values.map((l) => l.name).join(", ")})',
    );
  }
}
