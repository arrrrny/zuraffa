/// Legacy hand-written model — the pre-v5 code the zfa-only rewrite lifts.
///
/// Part of the fixed sample package fixture for the
/// `agent-rewrite-zfa-only` GYM exercise (spec 021 / issue #478).
/// Deliberately plain Dart with zero imports so the fixture is
/// self-contained and analysis-inert.
library;

/// Hand-written tag model predating the v5 architecture.
///
/// The rewrite manifest (../rewrite-manifest.json) declares the `Tag`
/// entity with these fields; the exercise lifts them via
/// `zfa entity create -n Tag --field ...`.
class LegacyTag {
  final String id;
  final String label;

  const LegacyTag({required this.id, required this.label});
}
