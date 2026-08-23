import 'dart:convert';

import 'session_exception.dart';

/// Bookkeeping attached to a [Session].
///
/// Timestamps are epoch milliseconds (portable across runtimes). [expiresAt]
/// is optional: `null` means the session never expires on its own.
class SessionMetadata {
  /// Creation time (epoch ms).
  final int createdAt;

  /// Last mutation time (epoch ms).
  final int updatedAt;

  /// Optional expiry (epoch ms); `null` = no expiry.
  final int? expiresAt;

  const SessionMetadata({
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
  });

  /// Metadata stamped *now* with an optional [expiresAt] offset in
  /// milliseconds from the epoch.
  factory SessionMetadata.now({int? expiresAt}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return SessionMetadata(
      createdAt: now,
      updatedAt: now,
      expiresAt: expiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    if (expiresAt != null) 'expiresAt': expiresAt,
  };

  factory SessionMetadata.fromJson(Map<String, dynamic> json) {
    final created = _readMillis(json, 'createdAt');
    final updated = _readMillis(json, 'updatedAt', fallback: created);
    return SessionMetadata(
      createdAt: created,
      updatedAt: updated,
      expiresAt: json['expiresAt'] == null
          ? null
          : _readMillis(json, 'expiresAt'),
    );
  }

  static int _readMillis(
    Map<String, dynamic> json,
    String key, {
    int? fallback,
  }) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (fallback != null) return fallback;
    throw ZuraffaSessionException.malformedEnvelope(
      'metadata field "$key" is missing or not a number',
    );
  }

  SessionMetadata copyWith({int? updatedAt, int? expiresAt}) => SessionMetadata(
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
}

/// A single unit of session state: a [type] (preset name), a unique [id],
/// a caller-chosen [key] inside its scope, and a schema-free [payload].
///
/// The payload is a plain `Map<String, dynamic>` so any session domain —
/// tokens, cookies, browser state, app-specific blobs — can be held without
/// a predefined schema (spec FR-001). Domain layers (e.g. the
/// `zikzak_session` package) map their typed structures onto the payload
/// and keep the core generic.
class Session {
  /// The preset/type identifier (e.g. `authToken`, `browser`).
  final String type;

  /// Unique session id (stable across serialization round-trips).
  final String id;

  /// Caller-chosen key identifying this session within `(scope, type)`.
  final String key;

  /// Schema-free session data.
  final Map<String, dynamic> payload;

  /// Creation/update/expiry bookkeeping.
  final SessionMetadata metadata;

  const Session({
    required this.type,
    required this.id,
    required this.key,
    required this.payload,
    required this.metadata,
  });

  /// True when the session's expiry has passed as of [at] (epoch ms).
  bool isExpired({int? at}) {
    final expiresAt = metadata.expiresAt;
    if (expiresAt == null) return false;
    final now = at ?? DateTime.now().millisecondsSinceEpoch;
    return now >= expiresAt;
  }

  Session copyWith({
    Map<String, dynamic>? payload,
    int? updatedAt,
    int? expiresAt,
  }) => Session(
    type: type,
    id: id,
    key: key,
    payload: payload ?? this.payload,
    metadata: metadata.copyWith(updatedAt: updatedAt, expiresAt: expiresAt),
  );

  /// Portable single-session JSON. Round-trips through [fromJson] with full
  /// fidelity (type, id, key, payload, metadata) so a session serialized in
  /// one runtime deserializes identically in another (spec FR-006/SC-003).
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'key': key,
    'payload': payload,
    'metadata': metadata.toJson(),
  };

  /// Rebuilds a session from its portable JSON form.
  ///
  /// Throws [ZuraffaSessionException.malformedEnvelope] when required fields
  /// are missing or of the wrong shape — a recoverable error, never a crash
  /// (spec edge case: malformed serialized session).
  factory Session.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    final id = json['id'];
    final key = json['key'];
    if (type is! String || id is! String || key is! String) {
      throw ZuraffaSessionException.malformedEnvelope(
        'session "type", "id" and "key" must be strings',
      );
    }
    final rawPayload = json['payload'];
    if (rawPayload != null && rawPayload is! Map<String, dynamic>) {
      throw ZuraffaSessionException.malformedEnvelope(
        'session "payload" must be an object',
      );
    }
    final rawMetadata = json['metadata'];
    final metadata = rawMetadata is Map<String, dynamic>
        ? SessionMetadata.fromJson(rawMetadata)
        : SessionMetadata.now();
    return Session(
      type: type,
      id: id,
      key: key,
      payload: Map<String, dynamic>.from(rawPayload as Map? ?? const {}),
      metadata: metadata,
    );
  }

  /// Convenience: encode to a JSON string for transport.
  String encode() => jsonEncode(toJson());

  /// Convenience: decode from a JSON string produced by [encode].
  static Session decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw ZuraffaSessionException.malformedEnvelope(
        'not valid JSON (${error.message})',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw ZuraffaSessionException.malformedEnvelope(
        'expected a JSON object at the top level',
      );
    }
    return Session.fromJson(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Session &&
          other.type == type &&
          other.id == id &&
          other.key == key &&
          _deepEquals(other.payload, payload);

  @override
  int get hashCode => Object.hash(type, id, key);

  static bool _deepEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      return a.entries.every((entry) {
        final other = b[entry.key];
        return b.containsKey(entry.key) && _deepEquals(entry.value, other);
      });
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
