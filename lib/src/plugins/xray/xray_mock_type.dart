// X-Ray mock type — enum for the three supported mock entry kinds.
//
// `valid`   → green   (the payload represents a successful hardware response)
// `error`   → red     (the payload represents a hardware failure)
// `unknown` → neutral (no type metadata, the deck UI shows a grey button)
//
// The colors are ARGB ints so the Flutter painter can consume them via
// `Color(c)` directly.
//
// Track 4.3 — Spec 034 (issue #185, FR-001, FR-004).
library;

/// Type of an [XRayMockEntry]. Drives the button color in the Control
/// Deck UI.
enum XRayMockType {
  /// Represents a valid mock payload. Button color: neon green.
  valid(0xFF00C853),

  /// Represents an error mock payload. Button color: red.
  error(0xFFD50000),

  /// Default when no `type` is provided. Button color: neutral grey.
  unknown(0xFF9E9E9E);

  /// ARGB int color used by the Flutter button painter.
  final int color;

  const XRayMockType(this.color);

  /// Lower-case label string used in JSON serialization + log output.
  String get label => name;

  /// Parse a string into an [XRayMockType]. Returns [unknown] for null,
  /// empty, or unrecognized strings. Case-insensitive.
  static XRayMockType fromString(String? s) {
    if (s == null) return XRayMockType.unknown;
    final lower = s.toLowerCase();
    for (final t in XRayMockType.values) {
      if (t.name == lower) return t;
    }
    return XRayMockType.unknown;
  }
}
