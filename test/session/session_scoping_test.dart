import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// User Story 3 (P3) — custom presets, scoping/isolation, and pluggable
/// persistence.
void main() {
  group('custom presets', () {
    test('registered custom presets behave like built-ins', () {
      final registry = SessionPresetRegistry.withBuiltIns()
        ..register(
          const SessionPreset(
            name: 'pool',
            description: 'Forklift task-pool marker session.',
            fields: ['mode'],
            defaultExpiryMs: 60000,
          ),
        );

      final container = SessionContainer(registry: registry);
      final created = container.create('pool', 'worker', {
        'mode': 'LOCAL_ONLY',
      });

      expect(container.get('pool', 'worker')!.payload['mode'], 'LOCAL_ONLY');
      expect(
        created.metadata.expiresAt,
        isNotNull,
        reason: 'the preset default expiry applies on creation',
      );

      // Duplicate registration is rejected loudly.
      expect(
        () => registry.register(
          SessionPreset(name: 'pool', description: 'shadow'),
        ),
        throwsA(
          isA<ZuraffaSessionException>().having(
            (e) => e.code,
            'code',
            'duplicate_preset',
          ),
        ),
      );
    });

    test('a second registry does not leak custom presets between domains', () {
      final registryA = SessionPresetRegistry.withBuiltIns()
        ..register(SessionPreset(name: 'alphaOnly', description: 'A'));
      final registryB = SessionPresetRegistry.withBuiltIns();

      expect(registryA.contains('alphaOnly'), isTrue);
      expect(
        registryB.contains('alphaOnly'),
        isFalse,
        reason: 'registries are isolated per container/domain',
      );
    });
  });

  group('scoping and isolation', () {
    test('sessions in scope A never leak into scope B', () {
      final container = SessionContainer();
      container.create('authToken', 'user', {'token': 'A'}, scope: 'A');
      container.create('authToken', 'user', {'token': 'B'}, scope: 'B');

      expect(
        container.get('authToken', 'user', scope: 'A')!.payload['token'],
        'A',
      );
      expect(
        container.get('authToken', 'user', scope: 'B')!.payload['token'],
        'B',
      );
      expect(container.list(scope: 'A'), hasLength(1));
      expect(container.list(scope: 'B'), hasLength(1));
      expect(
        container.list(scope: 'C'),
        isEmpty,
        reason: 'empty scopes are simply empty, never errors',
      );
    });

    test('clearScope removes only its own sessions', () {
      final container = SessionContainer();
      container.create('authToken', 'u1', {'token': '1'}, scope: 'app');
      container.create('cookie', 'c1', {'name': 'sid'}, scope: 'app');
      container.create('authToken', 'u1', {'token': 'other'}, scope: 'other');

      final removed = container.clearScope('app');
      expect(removed, 2);
      expect(container.get('authToken', 'u1', scope: 'app'), isNull);
      expect(container.get('cookie', 'c1', scope: 'app'), isNull);
      expect(
        container.get('authToken', 'u1', scope: 'other')!.payload['token'],
        'other',
        reason: 'other scopes are untouched',
      );
    });
  });

  group('pluggable persistence', () {
    test('a snapshot survives a simulated restart', () async {
      final persistence = InMemorySessionPersistence();
      final first = SessionContainer();
      first.create('authToken', 'web', {'token': 'persisted'});
      first.create('cookie', 'sid', {
        'name': 'sid',
        'value': 'v',
      }, scope: 'browser');
      await first.persist(persistence);

      // "Restart": a brand-new container restores from the backend.
      final second = SessionContainer();
      final restored = await second.restore(persistence);

      expect(restored, isTrue);
      expect(second.get('authToken', 'web')!.payload['token'], 'persisted');
      expect(
        second.get('cookie', 'sid', scope: 'browser')!.payload['value'],
        'v',
        reason: 'scope information survives persistence',
      );
    });

    test(
      'restore with nothing persisted leaves the container untouched',
      () async {
        final container = SessionContainer()
          ..create('apiKey', 'k', {'key': 'x'});
        final restored = await container.restore(InMemorySessionPersistence());

        expect(restored, isFalse);
        expect(container.get('apiKey', 'k')!.payload['key'], 'x');
      },
    );

    test(
      'a custom persistence backend plugs in behind the same seam',
      () async {
        final fileLike = _MapFilePersistence();
        final container = SessionContainer()
          ..create('oauth', 'gh', {'accessToken': 'at'});
        await container.persist(fileLike);

        final revived = SessionContainer();
        await revived.restore(fileLike);
        expect(revived.get('oauth', 'gh')!.payload['accessToken'], 'at');
        expect(fileLike.saveCount, 1);
      },
    );
  });
}

/// Minimal alternate backend proving the seam is implementation-agnostic.
class _MapFilePersistence implements SessionPersistence {
  Map<String, dynamic>? _stored;
  int saveCount = 0;

  @override
  Future<Map<String, dynamic>?> load() async => _stored;

  @override
  Future<void> save(Map<String, dynamic> envelope) async {
    saveCount += 1;
    _stored = envelope;
  }
}
