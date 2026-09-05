// Unit tests for `Tier2MockProvider` — the Firestore-shaped adapter the
// realize-mock differential gate swaps in (issue #1009).
//
// Contract under test: the same invocation surface as the Tier-1 mock
// driver contract (method name + args in, result JSON out), routed
// through a FakeFirebaseFirestore so reads/writes observe Firestore's
// typed-value semantics — including the "wrong type" divergence the
// differential gate must be able to surface.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/tier2_firestore/tier2_mock_provider.dart';

void main() {
  group('collection naming (the skeleton Firestore convention)', () {
    test('Login -> login', () {
      expect(Tier2MockProvider.collectionOf('Login'), 'login');
    });

    test('UserProfile -> user_profile', () {
      expect(Tier2MockProvider.collectionOf('UserProfile'), 'user_profile');
    });
  });

  group('read-by-id (get<Entity>ById / getById)', () {
    test('a seeded document returns its field map', () async {
      final provider = Tier2MockProvider(entity: 'Login');
      await provider.seed([
        <String, dynamic>{'id': 'u1', 'email': 'a@b.c', 'attempts': 3},
      ]);
      final result = await provider.invoke('getById', <String, dynamic>{
        'id': 'u1',
      });
      expect(result, <String, dynamic>{
        'id': 'u1',
        'email': 'a@b.c',
        'attempts': 3,
      });
    });

    test('the entity-qualified spelling hits the same route', () async {
      final provider = Tier2MockProvider(entity: 'Login');
      await provider.seed([
        <String, dynamic>{'id': 'u1', 'email': 'a@b.c'},
      ]);
      final result = await provider.invoke('getLoginById', <String, dynamic>{
        'id': 'u1',
      });
      expect(result, <String, dynamic>{'id': 'u1', 'email': 'a@b.c'});
    });

    test('a miss returns the empty document {}', () async {
      final provider = Tier2MockProvider(entity: 'Login');
      await provider.seed([
        <String, dynamic>{'id': 'u1', 'email': 'a@b.c'},
      ]);
      final result = await provider.invoke('getById', <String, dynamic>{
        'id': 'missing',
      });
      expect(result, isEmpty);
    });

    test('a non-String id is a named method error (fail-closed)', () async {
      final provider = Tier2MockProvider(entity: 'Login');
      await expectLater(
        provider.invoke('getById', <String, dynamic>{'id': 42}),
        throwsA(
          isA<Tier2MockMethodError>().having(
            (e) => e.method,
            'method',
            'getById',
          ),
        ),
      );
    });
  });

  group('list (getAll<Entity>s / getAll)', () {
    test('seeded documents list in document-id order under items', () async {
      final provider = Tier2MockProvider(entity: 'Login');
      await provider.seed([
        <String, dynamic>{'id': 'u3', 'email': 'c@d.e'},
        <String, dynamic>{'id': 'u1', 'email': 'a@b.c'},
        <String, dynamic>{'id': 'u2', 'email': 'b@c.d'},
      ]);
      final result = await provider.invoke(
        'getAllLogins',
        const <String, dynamic>{},
      );
      expect(
        result['items'],
        isA<List<dynamic>>()
            .having((items) => items.length, 'length', 3)
            .having(
              (items) => (items[0] as Map)['id'],
              'first document id',
              'u1',
            ),
      );
    });

    test('the generic spelling getAll hits the same route', () async {
      final provider = Tier2MockProvider(entity: 'Login');
      await provider.seed([
        <String, dynamic>{'id': 'u1'},
      ]);
      final result = await provider.invoke('getAll', const <String, dynamic>{});
      expect((result['items'] as List), hasLength(1));
    });
  });

  group('save / delete / exists', () {
    test(
      'save writes through the typed store and returns the doc id',
      () async {
        final provider = Tier2MockProvider(entity: 'Login');
        final result = await provider.invoke('saveLogin', <String, dynamic>{
          'id': 'u2',
          'email': 'd@e.f',
        });
        expect(result, <String, dynamic>{'id': 'u2'});
        // The write landed in the fake Firestore (typed round-trip).
        final readBack = await provider.invoke('getById', <String, dynamic>{
          'id': 'u2',
        });
        expect(readBack, <String, dynamic>{'id': 'u2', 'email': 'd@e.f'});
      },
    );

    test('save accepts an explicit record map argument', () async {
      final provider = Tier2MockProvider(entity: 'Login');
      final result = await provider.invoke('save', <String, dynamic>{
        'record': <String, dynamic>{'id': 'u9', 'email': 'x@y.z'},
      });
      expect(result, <String, dynamic>{'id': 'u9'});
    });

    test('delete removes the document and returns the doc id', () async {
      final provider = Tier2MockProvider(entity: 'Login');
      await provider.seed([
        <String, dynamic>{'id': 'u1'},
      ]);
      final result = await provider.invoke('deleteLogin', <String, dynamic>{
        'id': 'u1',
      });
      expect(result, <String, dynamic>{'id': 'u1'});
      final miss = await provider.invoke('getById', <String, dynamic>{
        'id': 'u1',
      });
      expect(miss, isEmpty);
    });

    test('exists reports presence and absence', () async {
      final provider = Tier2MockProvider(entity: 'Login');
      await provider.seed([
        <String, dynamic>{'id': 'u1'},
      ]);
      expect(
        await provider.invoke('exists', <String, dynamic>{'id': 'u1'}),
        <String, dynamic>{'exists': true},
      );
      expect(
        await provider.invoke('exists', <String, dynamic>{'id': 'zz'}),
        <String, dynamic>{'exists': false},
      );
    });
  });

  group("type fidelity (the differential gate's teeth)", () {
    test('a double seeded where the tier-1 oracle has an int reads back '
        'as a double — a REAL wrong-type divergence', () async {
      final provider = Tier2MockProvider(entity: 'Login');
      // The Tier-1 oracle would record attempts: 42 (int). The Tier-2
      // store holds 42.0 (double) — Firestore keeps them distinct
      // (doubleValue vs integerValue), so the divergence surfaces.
      await provider.seed([
        <String, dynamic>{'id': 'u1', 'attempts': 42.0},
      ]);
      final result = await provider.invoke('getById', <String, dynamic>{
        'id': 'u1',
      });
      expect(result['attempts'], isA<double>());
      // Dart's == equates 42.0 with 42 (num equality), but the RUNTIME
      // TYPE differs — and the realize-mock comparison runs on the JSON
      // encoding, where '42.0' != '42', so the divergence surfaces there.
      expect(result['attempts'].runtimeType, double);
    });
  });

  group('fail-closed surface', () {
    test('a method outside the CRUD surface is a named error', () async {
      final provider = Tier2MockProvider(entity: 'Login');
      await expectLater(
        provider.invoke('authenticate', const <String, dynamic>{}),
        throwsA(
          isA<Tier2MockMethodError>()
              .having((e) => e.method, 'method', 'authenticate')
              .having((e) => '$e', 'toString', contains('authenticate')),
        ),
      );
    });

    test('a save document without a String id is a named error', () async {
      final provider = Tier2MockProvider(entity: 'Login');
      await expectLater(
        provider.invoke('saveLogin', <String, dynamic>{'email': 'no-id'}),
        throwsA(isA<Tier2MockMethodError>()),
      );
    });

    test('seed records without a String id are rejected', () async {
      final provider = Tier2MockProvider(entity: 'Login');
      expect(
        () => provider.seed([
          <String, dynamic>{'email': 'no-id'},
        ]),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('seed determinism', () {
    test('seed replaces prior content (per-case state isolation)', () async {
      final provider = Tier2MockProvider(entity: 'Login');
      await provider.seed([
        <String, dynamic>{'id': 'u1'},
        <String, dynamic>{'id': 'u2'},
      ]);
      await provider.seed([
        <String, dynamic>{'id': 'only'},
      ]);
      final result = await provider.invoke('getAll', const <String, dynamic>{});
      expect(result['items'], hasLength(1));
      expect((result['items'] as List).first, containsPair('id', 'only'));
    });
  });
}
