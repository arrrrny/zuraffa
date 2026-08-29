// X-Ray mock entry — immutable data class for a single mock scenario.
//
// Equality is by `name + payload` pair (per spec edge case: "deduplication
// is by name+payload pair, not name alone"). The [type] field is metadata
// for color coding only — it does NOT affect equality.
//
// Track 4.3 — Spec 034 (issue #185, FR-001, FR-006).
library;

import 'xray_mock_type.dart';

/// A single mock scenario registered for the X-Ray Control Deck.
class XRayMockEntry {
  /// Human-readable name shown on the deck button (e.g.
  /// `"Valid Product A"`).
  final String name;

  /// The synthetic payload to inject when the user taps the button.
  /// May be an empty string (empty-payload testing — see spec edge case).
  final String payload;

  /// Type metadata driving the button color in the deck UI.
  /// Defaults to [XRayMockType.unknown] when not specified.
  final XRayMockType type;

  const XRayMockEntry({
    required this.name,
    required this.payload,
    this.type = XRayMockType.unknown,
  });

  /// Serialize to JSON for the MCP bridge / detail panel.
  Map<String, dynamic> toJson() => {
    'name': name,
    'payload': payload,
    'type': type.label,
  };

  /// Deserialize from JSON.
  factory XRayMockEntry.fromJson(Map<String, dynamic> json) {
    return XRayMockEntry(
      name: json['name'] as String,
      payload: json['payload'] as String,
      type: XRayMockType.fromString(json['type'] as String?),
    );
  }

  /// Equality by name + payload pair (per spec edge case).
  /// The [type] field does NOT participate in equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XRayMockEntry && other.name == name && other.payload == payload;

  /// Hash by name + payload (matches [operator ==]).
  @override
  int get hashCode => Object.hash(name, payload);

  @override
  String toString() =>
      'XRayMockEntry(name=$name, payload=$payload, '
      'type=${type.label})';
}
