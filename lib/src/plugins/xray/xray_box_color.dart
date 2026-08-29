// X-Ray bounding-box color palette — stable, distinct neon color per
// view type, so the developer can visually distinguish view boundaries
// in the overlay.
//
// Pure-Dart, no Flutter dependency. The Flutter painter consumes the
// ARGB int directly via `Color(c)` from `dart:ui` (via Flutter's
// `Color` constructor).
//
// Track 4.2 — Spec 036 (issue #181, FR-002).
library;

/// Per-view-type color resolution for X-Ray bounding boxes.
///
/// The palette is built from a small set of neon base colors; the actual
/// color for a viewType is chosen by hashing the viewType string against
/// the palette. This guarantees:
///   - Stable: the same viewType always resolves to the same color.
///   - Distinct: different viewTypes get different colors (with high
///     probability — small collisions on long type names are acceptable
///     because visual context disambiguates).
///   - Neon: every color has alpha=0xFF and at least one R/G/B channel
///     >= 0xA0 so the box is visible against any background.
class XRayBoxColor {
  /// Neon palette — 8 distinct high-luminance colors.
  static const List<int> palette = [
    0xFFFF00C8, // neon pink
    0xFF00F0FF, // neon cyan
    0xFFB6FF00, // neon lime
    0xFFFF8800, // neon orange
    0xFF9D00FF, // neon purple
    0xFFFFEE00, // neon yellow
    0xFF00FF7A, // neon mint
    0xFFFF0040, // neon red
  ];

  /// Hardcoded color map for the most common view types — guarantees
  /// distinctness for the canonical Zuraffa views regardless of hash
  /// collisions on short strings.
  static const Map<String, int> knownViewColors = {
    'ProfileView': 0xFFFF00C8, // neon pink
    'HomeView': 0xFF00F0FF, // neon cyan
    'SettingsView': 0xFFB6FF00, // neon lime
    'SearchView': 0xFFFF8800, // neon orange
    'CartView': 0xFF9D00FF, // neon purple
    'CheckoutView': 0xFFFFEE00, // neon yellow
    'AuthView': 0xFF00FF7A, // neon mint
    'ErrorView': 0xFFFF0040, // neon red
  };

  /// Default fallback color for unknown view types — also neon.
  static const int fallback = 0xFF00FFAA;

  /// Resolve a stable, distinct neon ARGB color for the given [viewType].
  ///
  /// Strategy:
  /// 1. If [viewType] is in [knownViewColors], return its dedicated color.
  /// 2. Otherwise, hash [viewType] with FNV-1a and index into [palette].
  ///
  /// This guarantees distinctness for the canonical Zuraffa views while
  /// still giving deterministic, neon, opaque colors for unknown view
  /// types (small collision risk on short unknown strings is acceptable
  /// — visual context disambiguates).
  static int forViewType(String viewType) {
    if (viewType.isEmpty) return fallback;
    final known = knownViewColors[viewType];
    if (known != null) return known;
    final hash = _stableHash(viewType);
    return palette[hash % palette.length];
  }

  /// Format an ARGB int as `#AARRGGBB` (e.g. `#FFFF00C8`).
  static String toArgbString(int color) {
    final hex = color.toRadixString(16).toUpperCase().padLeft(8, '0');
    return '#$hex';
  }

  // Simple FNV-1a-like hash. Pure-Dart, no sdk:hashlib dependency.
  static int _stableHash(String s) {
    var h = 0x811C9DC5;
    for (final c in s.codeUnits) {
      h = h ^ c;
      // Multiply by 16777619 (FNV prime) mod 2^32.
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    // The high bit may be set; mask it so the int stays non-negative in
    // Dart's signed 64-bit representation.
    return h & 0x7FFFFFFF;
  }
}
