/// MockPriority (feature 072, issue #960): the declared mock priority of
/// an External Dependencies & Contracts row — orders dependency-mock
/// materialization in the loop.
///
/// Core-level model: both the tdd plugin (plan/loop ordering) and the
/// mock plugin (generated artifacts) read it; a plugin-to-plugin import
/// would be an architecture violation.
library;

/// P1 → P2 → P3 → none (unprioritized last), stable within tier by
/// declaration order.
enum MockPriority {
  p1(0),
  p2(1),
  p3(2),
  none(3);

  /// Sort tier: lower runs first.
  final int tier;

  const MockPriority(this.tier);

  /// Parse the declared priority cell. Case-insensitive; empty/null →
  /// [none]. An unknown token → null (the caller refuses naming the
  /// cell — a typo'd priority is contract drift, not a silent default).
  static MockPriority? tryParse(String? raw) {
    final t = raw?.trim().toUpperCase();
    if (t == null || t.isEmpty) return none;
    switch (t) {
      case 'P1':
        return p1;
      case 'P2':
        return p2;
      case 'P3':
        return p3;
      default:
        return null;
    }
  }

  /// Kebab label for artifacts/summaries.
  String get label => this == none ? 'none' : name;

  /// The priority cell text as declared form (P1/P2/P3/'').
  @override
  String toString() => label.toUpperCase();
}
