import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Secure storage (ecosystem gap #1): port contract, in-memory backend,
/// the JSON codec platform adapters share, and the SecretStore facade.
void main() {
  group('SecureStoragePort — in-memory backend', () {
    test('write/read round-trips a JSON map', () async {
      final storage = InMemorySecureStorage();
      await storage.write('auth', {'token': 'tok-1', 'provider': 'kimi'});

      expect(await storage.read('auth'), {
        'token': 'tok-1',
        'provider': 'kimi',
      });
      expect(await storage.contains('auth'), isTrue);
    });

    test(
      'reading an absent key returns null; remove reports honestly',
      () async {
        final storage = InMemorySecureStorage();

        expect(await storage.read('nope'), isNull);
        expect(await storage.contains('nope'), isFalse);
        expect(await storage.remove('nope'), isFalse);

        await storage.write('here', {'a': 1});
        expect(await storage.remove('here'), isTrue);
        expect(await storage.read('here'), isNull);
      },
    );

    test('overwrite replaces the previous value', () async {
      final storage = InMemorySecureStorage();
      await storage.write('k', {'v': 1});
      await storage.write('k', {'v': 2});

      expect((await storage.read('k'))!['v'], 2);
    });

    test('clear removes everything', () async {
      final storage = InMemorySecureStorage()
        ..write('a', {'x': 1})
        ..write('b', {'x': 2});
      await storage.clear();

      expect(await storage.contains('a'), isFalse);
      expect(await storage.contains('b'), isFalse);
    });

    test('a corrupt entry is a typed, recoverable error', () async {
      final storage = InMemorySecureStorage();
      await storage.write('damaged', {'v': 1});
      storage.corruptKeys.add('damaged');

      await expectLater(
        storage.read('damaged'),
        throwsA(
          isA<SecureStorageException>().having(
            (e) => e.code,
            'code',
            'corrupt',
          ),
        ),
      );
      // Other entries are untouched.
      expect(
        await storage.read('other'),
        isNull,
        reason: 'corruption is per-entry, never store-wide',
      );
    });
  });

  group('SecureStorageCodec — the platform wire form', () {
    test('encode/decode round-trips key and value', () {
      final encoded = SecureStorageCodec.encode('k1', {'token': 't'});
      final (key, value) = SecureStorageCodec.decode(encoded);

      expect(key, 'k1');
      expect(value, {'token': 't'});
    });

    test('malformed stored bytes are typed corrupt errors', () {
      expect(
        () => SecureStorageCodec.decode('{broken'),
        throwsA(isA<SecureStorageException>()),
      );
      expect(
        () => SecureStorageCodec.decode('{"k": 1, "v": {}}'),
        throwsA(isA<SecureStorageException>()),
        reason: 'non-String key is corrupt',
      );
      expect(
        () => SecureStorageCodec.decode('{"k": "k", "v": "not-an-object"}'),
        throwsA(isA<SecureStorageException>()),
        reason: 'non-object value is corrupt',
      );
    });
  });

  group('SecretStore — the app-facing facade', () {
    test('token save/read round-trip; absent token is null', () async {
      final secrets = SecretStore();

      await secrets.saveToken('auth', 'tok-9');
      expect(await secrets.readToken('auth'), 'tok-9');
      expect(await secrets.readToken('absent'), isNull);
    });

    test('typed object accessors via toJson/fromJson', () async {
      final secrets = SecretStore();

      await secrets.saveObject('profile', {
        'name': 'Ada',
        'id': 7,
      }, (profile) => profile);
      final restored = await secrets.readObject<Map<String, dynamic>>(
        'profile',
        (json) => json,
      );

      expect(restored!['name'], 'Ada');
      expect(restored['id'], 7);
    });

    test('raw map access surfaces through the facade', () async {
      final secrets = SecretStore();

      await secrets.write('raw', {'a': true});
      expect(await secrets.read('raw'), {'a': true});
      expect(await secrets.contains('raw'), isTrue);
      expect(await secrets.remove('raw'), isTrue);
      expect(await secrets.read('raw'), isNull);
    });
  });

  group('registerSecureStorageDependencies', () {
    test('wires port + SecretStore onto GetIt, honoring injection', () async {
      final getIt = GetIt.asNewInstance();
      final custom = InMemorySecureStorage();
      registerSecureStorageDependencies(getIt, storage: custom);

      final secrets = getIt<SecretStore>();
      await secrets.saveToken('di', 'tok-di');
      expect(await secrets.readToken('di'), 'tok-di');
      expect(
        await custom.read('di'),
        isNotNull,
        reason: 'the injected backend is the one used',
      );
    });
  });
}
