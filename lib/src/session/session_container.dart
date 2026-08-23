import 'dart:convert';

import 'session.dart';
import 'session_exception.dart';
import 'session_preset.dart';

/// The serialized wire format's schema version. Bumped on breaking
/// envelope changes; readers reject envelopes from the future with a
/// recoverable [ZuraffaSessionException].
const int kSessionEnvelopeVersion = 1;

/// A generic, platform-agnostic session container (spec FR-001/FR-005/
/// FR-006/FR-007).
///
/// Sessions are keyed by `(scope, type, key)`: [scope] namespaces
/// independent sessions (default `'default'`), `type` is the preset name,
/// and [key] is the caller-chosen identifier inside that scope. The same
/// API works in pure-Dart `zuraffa` apps and in `zuraffa_flutter` apps —
/// this class has no Flutter or UI dependencies (spec FR-004/SC-004).
///
/// Reads treat expired sessions as not-found (never throwing) and
/// enumeration skips them, so expiry is lazy — no background sweeper.
class SessionContainer {
  /// Registry consulted for validation on [put] and for preset discovery.
  final SessionPresetRegistry registry;

  final Map<String, Session> _sessions = {};

  SessionContainer({SessionPresetRegistry? registry})
    : registry = registry ?? SessionPresetRegistry.withBuiltIns();

  /// Stores a new session under `(scope, type, key)`.
  ///
  /// The preset must be registered (strict mode — spec edge case:
  /// unregistered type yields a clear error) and the payload must satisfy
  /// the preset's rules; the preset's default expiry applies when the
  /// session carries none. Overwrites an existing session at the same
  /// coordinates (last-write-wins).
  Session put(Session session, {String scope = 'default'}) {
    final preset = registry.lookup(session.type);
    if (preset == null) {
      throw ZuraffaSessionException.unknownPreset(session.type);
    }
    final error = preset.validatePayload(session.payload);
    if (error != null) {
      throw ZuraffaSessionException('invalid_payload', error);
    }
    var effective = session;
    if (session.metadata.expiresAt == null && preset.defaultExpiryMs != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      effective = session.copyWith(
        expiresAt: now + preset.defaultExpiryMs!,
        updatedAt: now,
      );
    }
    _sessions[_coordinate(scope, session.type, session.key)] = effective;
    return effective;
  }

  /// Convenience: creates and stores a session from [payload] under a
  /// registered preset [type].
  Session create(
    String type,
    String key,
    Map<String, dynamic> payload, {
    String scope = 'default',
    String? id,
  }) {
    return put(
      Session(
        type: type,
        id: id ?? _newId(),
        key: key,
        payload: payload,
        metadata: SessionMetadata.now(),
      ),
      scope: scope,
    );
  }

  /// Reads the session at `(scope, type, key)`, or `null` when absent or
  /// expired (spec edge case: empty store / expired = not-found).
  Session? get(String type, String key, {String scope = 'default'}) {
    final session = _sessions[_coordinate(scope, type, key)];
    if (session == null) return null;
    if (session.isExpired()) return null;
    return session;
  }

  /// Updates the payload of an existing live session, returning the
  /// updated session — or `null` when it does not exist (or expired).
  Session? update(
    String type,
    String key,
    Map<String, dynamic> payload, {
    String scope = 'default',
  }) {
    final existing = get(type, key, scope: scope);
    if (existing == null) return null;
    final updated = existing.copyWith(
      payload: payload,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _sessions[_coordinate(scope, type, key)] = updated;
    return updated;
  }

  /// Clears the session at `(scope, type, key)`; returns whether one was
  /// removed (expired sessions count as cleared too).
  bool clear(String type, String key, {String scope = 'default'}) {
    return _sessions.remove(_coordinate(scope, type, key)) != null;
  }

  /// All live (non-expired) sessions within [scope].
  List<Session> list({String scope = 'default'}) {
    final prefix = '$scope\u{1F}';
    return _sessions.entries
        .where((entry) => entry.key.startsWith(prefix))
        .map((entry) => entry.value)
        .where((session) => !session.isExpired())
        .toList(growable: false);
  }

  /// Clears every session in [scope] (other scopes untouched — spec
  /// FR-007 isolation). Returns the number removed.
  int clearScope(String scope) {
    final prefix = '$scope\u{1F}';
    final doomed = _sessions.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in doomed) {
      _sessions.remove(key);
    }
    return doomed.length;
  }

  /// Number of live sessions across all scopes.
  int get length =>
      _sessions.values.where((session) => !session.isExpired()).length;

  /// Whether any live session exists.
  bool get isEmpty => length == 0;

  /// Serializes every session (live and expired — expiry is re-evaluated
  /// on read after restore, so nothing is silently dropped) into a
  /// versioned, portable envelope (spec FR-006). Each entry carries its
  /// scope so isolated sessions round-trip into the right namespace.
  Map<String, dynamic> toJson() => {
    'version': kSessionEnvelopeVersion,
    'sessions': _sessions.entries
        .map((entry) => _entryWithScope(entry.key, entry.value))
        .toList(),
  };

  /// Convenience: JSON-string form for transport across runtimes.
  String encode() => jsonEncode(toJson());

  /// Replaces the container's contents with the sessions in [envelope].
  ///
  /// Sessions whose preset is unknown in *this* runtime are still loaded
  /// (losslessly — they round-trip back out), because the spec's edge
  /// case demands the data survive, not vanish. A malformed envelope or
  /// an unsupported version throws [ZuraffaSessionException] — a
  /// recoverable error, never a crash.
  void loadFromEnvelope(Map<String, dynamic> envelope) {
    final version = envelope['version'];
    if (version is! int || version > kSessionEnvelopeVersion) {
      throw ZuraffaSessionException.malformedEnvelope(
        'unsupported envelope version ${version ?? 'missing'} '
        '(reader supports <= $kSessionEnvelopeVersion)',
      );
    }
    final rawSessions = envelope['sessions'];
    if (rawSessions != null && rawSessions is! List) {
      throw ZuraffaSessionException.malformedEnvelope(
        '"sessions" must be an array',
      );
    }
    _sessions.clear();
    for (final raw in (rawSessions as List? ?? const [])) {
      if (raw is! Map<String, dynamic>) {
        throw ZuraffaSessionException.malformedEnvelope(
          'each entry under "sessions" must be an object',
        );
      }
      final rawSession = raw['session'];
      if (rawSession is! Map<String, dynamic>) {
        throw ZuraffaSessionException.malformedEnvelope(
          'each entry under "sessions" must nest a "session" object',
        );
      }
      final scope = raw['scope'] is String ? raw['scope'] as String : 'default';
      final session = Session.fromJson(rawSession);
      _sessions[_coordinate(scope, session.type, session.key)] = session;
    }
  }

  static Map<String, dynamic> _entryWithScope(
    String coordinate,
    Session session,
  ) {
    final parts = coordinate.split('\u{1F}');
    return {'scope': parts.first, 'session': session.toJson()};
  }

  /// Restores from a JSON string produced by [encode], optionally with a
  /// custom preset [registry] (defaults to built-ins).
  factory SessionContainer.decode(
    String source, {
    SessionPresetRegistry? registry,
  }) {
    return SessionContainer(registry: registry)
      ..loadFromEnvelope(_decodeJsonObject(source));
  }

  static Map<String, dynamic> _decodeJsonObject(String source) {
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
    return decoded;
  }

  static String _coordinate(String scope, String type, String key) =>
      '$scope\u{1F}$type\u{1F}$key';

  static String _newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'sess-$now-${_sequence++}';
  }

  static int _sequence = 0;
}
