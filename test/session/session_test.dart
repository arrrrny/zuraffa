import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// User Story 1 (P1) — generic session container with built-in presets:
/// every built-in instantiates with zero configuration, sessions store and
/// read back, clears make reads not-found, and an empty store read never
/// throws.
void main() {
  group('built-in presets', () {
    test('all six presets are registered with zero configuration', () {
      final registry = SessionPresetRegistry.withBuiltIns();
      for (final name in [
        'anonymous',
        'authToken',
        'cookie',
        'header',
        'oauth',
        'apiKey',
      ]) {
        expect(
          registry.contains(name),
          isTrue,
          reason: '$name must ship built-in',
        );
        expect(registry.lookup(name), isNotNull);
      }
      expect(registry.names, containsAll(<String>['anonymous', 'authToken']));
    });

    test('each built-in preset creates a working session out of the box', () {
      final container = SessionContainer();
      final samples = <String, Map<String, dynamic>>{
        'anonymous': {'visitorId': 'v-1'},
        'authToken': {'token': 'tok-123', 'provider': 'kimi'},
        'cookie': {'name': 'sid', 'value': 'abc'},
        'header': {'name': 'X-Api-Token', 'value': 't'},
        'oauth': {'accessToken': 'at', 'refreshToken': 'rt'},
        'apiKey': {'key': 'k-1'},
      };
      samples.forEach((type, payload) {
        container.create(type, 'primary', payload);
        final restored = container.get(type, 'primary');
        expect(restored, isNotNull, reason: '$type session must store');
        expect(
          restored!.payload,
          payload,
          reason: '$type payload must read back identically',
        );
        expect(restored.type, type);
        expect(restored.id, isNotEmpty);
        expect(restored.metadata.createdAt, greaterThan(0));
      });
    });

    test('preset validators reject invalid payloads with a typed error', () {
      final container = SessionContainer();
      expect(
        () => container.create('authToken', 'x', {'provider': 'kimi'}),
        throwsA(isA<ZuraffaSessionException>()),
        reason: 'authToken without a token must be rejected',
      );
      expect(
        () => container.create('cookie', 'x', {'value': 'abc'}),
        throwsA(isA<ZuraffaSessionException>()),
        reason: 'cookie without a name must be rejected',
      );
      expect(
        () => container.create('apiKey', 'x', {'secret': 's'}),
        throwsA(isA<ZuraffaSessionException>()),
        reason: 'apiKey without a key must be rejected',
      );
      // Whitelisted presets reject unknown fields.
      expect(
        () => container.create('authToken', 'x', {
          'token': 't',
          'hackerField': 'nope',
        }),
        throwsA(isA<ZuraffaSessionException>()),
      );
    });
  });

  group('session lifecycle', () {
    test('create, read, update, clear round flow', () {
      final container = SessionContainer();
      container.create('authToken', 'web', {'token': 'first'});

      final first = container.get('authToken', 'web')!;
      expect(first.payload['token'], 'first');

      final updated = container.update('authToken', 'web', {
        'token': 'second',
      })!;
      expect(updated.payload['token'], 'second');
      expect(updated.id, first.id, reason: 'update keeps the session id');
      expect(
        updated.metadata.updatedAt,
        greaterThanOrEqualTo(first.metadata.updatedAt),
      );

      expect(container.clear('authToken', 'web'), isTrue);
      expect(
        container.get('authToken', 'web'),
        isNull,
        reason: 'cleared sessions read as not-found',
      );
      expect(
        container.clear('authToken', 'web'),
        isFalse,
        reason: 'clearing again reports nothing removed',
      );
    });

    test('reading from an empty store returns null, never throws', () {
      final container = SessionContainer();
      expect(container.get('authToken', 'anything'), isNull);
      expect(container.update('authToken', 'anything', {}), isNull);
      expect(container.isEmpty, isTrue);
    });

    test('unknown preset on create is a typed, recoverable error', () {
      final container = SessionContainer();
      expect(
        () => container.create('telepathy', 'x', {}),
        throwsA(
          isA<ZuraffaSessionException>().having(
            (e) => e.code,
            'code',
            'unknown_preset',
          ),
        ),
      );
    });
  });
}
