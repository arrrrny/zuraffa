/// Legacy hand-written model — the pre-v5 code the zfa-only rewrite lifts.
///
/// Part of the fixed sample package fixture for the
/// `agent-rewrite-zfa-only` GYM exercise (spec 021 / issue #478).
/// Deliberately plain Dart with zero imports so the fixture is
/// self-contained and analysis-inert.
library;

/// Hand-written note model predating the v5 architecture.
///
/// The rewrite manifest (../rewrite-manifest.json) declares the `Note`
/// entity with these fields; the exercise lifts them via
/// `zfa entity create -n Note --field ...`.
class LegacyNote {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;

  const LegacyNote({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });
}
