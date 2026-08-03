// X-Ray mock entry — data model for a single mock scenario.

import "dart:convert";

/// The type of mock scenario, controlling color coding on the
/// Control Deck button.
enum XRayMockType {
  /// The payload should produce a successful result.
  valid,

  /// The payload should produce an error result.
  error,

  /// Unknown / unspecified type.
  unknown;

  static XRayMockType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case "valid":
        return XRayMockType.valid;
      case "error":
        return XRayMockType.error;
      default:
        return XRayMockType.unknown;
    }
  }
}

/// A single mock scenario entry in the Control Deck.
///
/// Created from @XRayMock annotations at build time, from YAML files,
/// or registered programmatically via [XRayControlDeckRegistry.registerEntries].
class XRayMockEntry {
  /// Human-readable name shown on the button.
  final String name;

  /// The synthetic payload to inject. Can be any type;
  /// stored as a dynamic value and passed to the injector callback.
  final dynamic payload;

  /// Type hint for color coding.
  final XRayMockType type;

  /// Optional description shown below the button name.
  final String? description;

  const XRayMockEntry({
    required this.name,
    required this.payload,
    this.type = XRayMockType.unknown,
    this.description,
  });

  /// Create from a YAML-parsed map (string keys).
  factory XRayMockEntry.fromYamlMap(Map<dynamic, dynamic> map) {
    return XRayMockEntry(
      name: (map["name"] as String?) ?? "Unnamed Mock",
      payload: map["payload"],
      type: XRayMockType.fromString(map["type"] as String?),
      description: map["description"] as String?,
    );
  }

  /// Create from an @XRayMock annotation.
  factory XRayMockEntry.fromAnnotation({
    required String name,
    required String payload,
    String? type,
  }) {
    return XRayMockEntry(
      name: name,
      payload: payload,
      type: XRayMockType.fromString(type),
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    "name": name,
    "payload": payload,
    "type": type.name,
    if (description != null) "description": description,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XRayMockEntry &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          payload == other.payload &&
          type == other.type;

  @override
  int get hashCode => Object.hash(name, payload, type);

  @override
  String toString() {
    String payloadStr;
    try {
      payloadStr = jsonEncode(payload);
    } catch (_) {
      payloadStr = payload.toString();
    }
    return "XRayMockEntry($name, $type, $payloadStr)";
  }
}

