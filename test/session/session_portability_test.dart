import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// User Story 2 (P2) — portable serialization: a session serialized in one
/// runtime deserializes with full fidelity in another; malformed input is
/// a recoverable error; expired sessions read as not-found; large payloads
/// round-trip without truncation.
void main() {
  SessionContainer roundTrip(SessionContainer source) {
    // The "transport": a plain JSON string, as it would cross a wire
    // between a server, a CLI, and a Flutter app.
    final wire = source.encode();
    return SessionContainer.decode(wire);
  }

  test('full round-trip preserves type, id, key, payload, metadata', () {
    final source = SessionContainer();
    final created = source.create('oauth', 'github', {
      'accessToken': 'at-1',
      'refreshToken': 'rt-1',
      'scope': 'read:user',
      'expiresIn': 3600,
    });
    // The anonymous preset is unbounded, so nested structures ride on it.
    final nested = source.create('anonymous', 'shapes', {
      'tree': {
        'roles': ['a', 'b'],
        'flag': true,
        'depth': {'n': 3},
      },
    });

    final restored = roundTrip(source);
    final session = restored.get('oauth', 'github')!;

    expect(session.type, created.type);
    expect(session.id, created.id, reason: 'id must survive transport');
    expect(session.key, created.key);
    expect(session.metadata.createdAt, created.metadata.createdAt);
    expect(session.metadata.updatedAt, created.metadata.updatedAt);
    expect(session.payload['accessToken'], 'at-1');

    final nestedBack = restored.get('anonymous', 'shapes')!;
    expect(nestedBack.id, nested.id);
    expect(nestedBack.payload['tree'], {
      'roles': ['a', 'b'],
      'flag': true,
      'depth': {'n': 3},
    }, reason: 'nested structures must round-trip exactly');
  });

  test('scopes survive the round-trip', () {
    final source = SessionContainer();
    source.create('authToken', 'a', {'token': 'ta'}, scope: 'app-a');
    source.create('authToken', 'a', {'token': 'tb'}, scope: 'app-b');

    final restored = roundTrip(source);
    expect(
      restored.get('authToken', 'a', scope: 'app-a')!.payload['token'],
      'ta',
    );
    expect(
      restored.get('authToken', 'a', scope: 'app-b')!.payload['token'],
      'tb',
    );
  });

  test('sessions of unknown presets survive the round-trip losslessly', () {
    // Creation stays strict (a typo in your own code fails fast) — but a
    // session ported from another runtime that HAS the preset registered
    // must deserialize, be readable, and re-serialize without data loss.
    final source = SessionContainer()
      ..create('authToken', 'known', {'token': 't'});
    final envelope = source.toJson();
    (envelope['sessions'] as List).add({
      'scope': 'default',
      'session': {
        'type': 'customWebCam',
        'id': 'sess-cam',
        'key': 'weird',
        'payload': {'device': '/dev/video0'},
        'metadata': {'createdAt': 1, 'updatedAt': 1},
      },
    });

    final restored = SessionContainer.decode(jsonEncode(envelope));
    // The known preset still resolves; the unknown one is carried through
    // as data (never dropped), readable via the raw list.
    expect(restored.get('authToken', 'known')!.payload['token'], 't');
    final unknown = restored
        .list()
        .where((s) => s.type == 'customWebCam')
        .single;
    expect(unknown.payload['device'], '/dev/video0');
    expect(unknown.id, 'sess-cam');

    // And it serializes back out identically (no data loss on re-port).
    final reSerialized = roundTrip(restored);
    expect(
      reSerialized
          .list()
          .where((s) => s.type == 'customWebCam')
          .single
          .payload['device'],
      '/dev/video0',
    );
  });

  test('malformed envelopes raise typed, recoverable errors', () {
    expect(
      () => SessionContainer.decode('{not json'),
      throwsA(isA<ZuraffaSessionException>()),
    );
    expect(
      () => SessionContainer.decode('[1,2,3]'),
      throwsA(isA<ZuraffaSessionException>()),
    );
    expect(
      () => SessionContainer.decode('{"version": 1, "sessions": "nope"}'),
      throwsA(isA<ZuraffaSessionException>()),
    );
    expect(
      () => SessionContainer.decode('{"version": 99, "sessions": []}'),
      throwsA(
        isA<ZuraffaSessionException>().having(
          (e) => e.code,
          'code',
          'malformed_envelope',
        ),
      ),
      reason: 'envelopes from the future must be rejected, not guessed at',
    );
  });

  test('expired sessions read as not-found and are skipped by list', () {
    final container = SessionContainer();
    final now = DateTime.now().millisecondsSinceEpoch;
    container.put(
      Session(
        type: 'authToken',
        id: 'sess-exp',
        key: 'stale',
        payload: {'token': 't'},
        metadata: SessionMetadata(
          createdAt: now - 10000,
          updatedAt: now - 10000,
          expiresAt: now - 1,
        ),
      ),
    );
    container.create('authToken', 'fresh', {'token': 't2'});

    expect(
      container.get('authToken', 'stale'),
      isNull,
      reason: 'expired sessions behave as not-found on read',
    );
    expect(container.list().map((s) => s.key), [
      'fresh',
    ], reason: 'enumeration skips expired sessions');
    expect(container.length, 1);
  });

  test('unusually large payloads round-trip without truncation', () {
    final source = SessionContainer();
    final big = <String, dynamic>{for (var i = 0; i < 100000; i++) 'k$i': i};
    source.create('anonymous', 'bulk', big);

    final restored = roundTrip(source);
    final session = restored.get('anonymous', 'bulk')!;
    expect(session.payload.length, 100000);
    expect(session.payload['k0'], 0);
    expect(session.payload['k99999'], 99999);
  });

  test('single sessions serialize independently of the container', () {
    final session = Session(
      type: 'cookie',
      id: 'sess-cookie',
      key: 'sid',
      payload: {'name': 'sid', 'value': 'v'},
      metadata: SessionMetadata.now(),
    );
    final wire = session.encode();
    final restored = Session.decode(wire);
    expect(restored, session, reason: 'Session equality covers the payload');
    expect(restored.payload['value'], 'v');
    expect(
      jsonDecode(wire),
      isA<Map<String, dynamic>>(),
      reason: 'the wire format is plain JSON',
    );
  });
}
