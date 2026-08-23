import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:zikzak_session/zikzak_session.dart';

/// Spec 015 (FR-009 / SC-005 / P2 story 2): the zikzak_session layer must
/// reuse — not reimplement — the zuraffa session plugin, and its browser
/// sessions must port across runtimes with full fidelity.
void main() {
  group('PortableBrowserSession portability', () {
    test('cookies, headers, and token round-trip through the wire exactly', () {
      final session = PortableBrowserSession()
          .withCookie(
            const ZikZakCookie(
              name: 'sid',
              value: 'abc123',
              domain: '.example.com',
              path: '/',
            ),
          )
          .withCookie(
            const ZikZakCookie(name: 'lang', value: 'en', expiresAt: 999999),
          )
          .withHeader('X-Client', 'zikzak')
          .withHeader('Authorization', 'Bearer tok-1')
          .withToken('tok-1');

      final wire = session.serialize();
      final restored = PortableBrowserSession.deserialize(wire);

      expect(restored.cookies, [
        // withCookie keeps the list sorted by name (lang < sid).
        const ZikZakCookie(name: 'lang', value: 'en', expiresAt: 999999),
        const ZikZakCookie(
          name: 'sid',
          value: 'abc123',
          domain: '.example.com',
          path: '/',
        ),
      ], reason: 'cookies must restore exactly, including attributes');
      expect(restored.headers, {
        'X-Client': 'zikzak',
        'Authorization': 'Bearer tok-1',
      });
      expect(restored.token, 'tok-1');
      expect(restored, session);
    });

    test('an anonymous (empty) session is valid and portable', () {
      const session = PortableBrowserSession.anonymous();
      final restored = PortableBrowserSession.deserialize(session.serialize());
      expect(restored.cookies, isEmpty);
      expect(restored.headers, isEmpty);
      expect(restored.token, isNull);
      expect(restored, session);
    });

    test('malformed wire input is a recoverable typed error', () {
      expect(
        () => PortableBrowserSession.deserialize('{nope'),
        throwsA(isA<ZuraffaSessionException>()),
      );
    });
  });

  group('container integration (reuse, not reimplement)', () {
    test('attaches to a zuraffa container and reads back identically', () {
      final container = SessionContainer();
      final session = PortableBrowserSession()
          .withCookie(const ZikZakCookie(name: 'sid', value: 'v'))
          .withToken('t');

      session.attach(container, key: 'web', scope: 'browser');
      final restored = PortableBrowserSession.read(
        container,
        key: 'web',
        scope: 'browser',
      )!;

      expect(restored, session);
      // The session lives in the standard container surface: it counts,
      // scopes, clears, and persists like any other session.
      expect(container.list(scope: 'browser'), hasLength(1));
      expect(container.get('browser', 'web', scope: 'browser'), isNotNull);
    });

    test('the whole container — browser sessions included — persists and '
        'restores through the core envelope', () async {
      final persistence = InMemorySessionPersistence();
      final first = SessionContainer();
      PortableBrowserSession()
          .withCookie(const ZikZakCookie(name: 'sid', value: 'v1'))
          .withHeader('X-A', 'a')
          .withToken('t1')
          .attach(first, key: 'web', scope: 'browser');
      first.create('authToken', 'api', {'token': 'other'});
      await first.persist(persistence);

      final second = SessionContainer();
      await second.restore(persistence);
      final restored = PortableBrowserSession.read(
        second,
        key: 'web',
        scope: 'browser',
      )!;

      expect(restored.cookies, [const ZikZakCookie(name: 'sid', value: 'v1')]);
      expect(restored.headers, {'X-A': 'a'});
      expect(restored.token, 't1');
      expect(
        second.get('authToken', 'api')!.payload['token'],
        'other',
        reason: 'unrelated sessions ride along in the same envelope',
      );
    });

    test(
      'expires through the standard container semantics when configured',
      () {
        final registry = SessionPresetRegistry.withBuiltIns();
        final container = SessionContainer(registry: registry);
        // A browser preset with a short expiry: attach a manually-expired
        // session through the same registry seam to prove lazy expiry.
        final now = DateTime.now().millisecondsSinceEpoch;
        registry.register(
          const SessionPreset(
            name: 'browser',
            description: 'short-lived browser session',
            fields: ['cookies', 'headers', 'token'],
            defaultExpiryMs: 1,
          ),
        );
        container.put(
          Session(
            type: 'browser',
            id: 'b1',
            key: 'web',
            payload: {'cookies': [], 'headers': <String, String>{}},
            metadata: SessionMetadata(
              createdAt: now - 5000,
              updatedAt: now - 5000,
              expiresAt: now - 1,
            ),
          ),
        );
        expect(
          PortableBrowserSession.read(container),
          isNull,
          reason: 'expired browser sessions read as not-found, like any other',
        );
      },
    );
  });
}
