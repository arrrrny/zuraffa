// Unit tests for `FakeFirebaseFirestore` — the Firestore-shaped store
// the Tier-2 mock provider is backed by (issue #1009).
//
// The contract under test is TYPE FIDELITY: the REST wire-shape typed
// values (`integerValue` / `doubleValue` / `stringValue` / ...) must
// round-trip Dart values exactly, because the realize-mock differential
// gate's per-method comparison must be able to catch a "wrong type"
// divergence (42 vs '42', 42 vs 42.0).
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/tier2_firestore/fake_firebase_firestore.dart';

void main() {
  group('encodeFirestoreValue / decodeFirestoreValue round-trip', () {
    test('null', () {
      final wire = encodeFirestoreValue(null);
      expect(wire, containsPair('nullValue', null));
      expect(decodeFirestoreValue(wire), isNull);
    });

    test('bool', () {
      final wire = encodeFirestoreValue(true);
      expect(wire, containsPair('booleanValue', true));
      expect(decodeFirestoreValue(wire), isTrue);
    });

    test('int stays an int (integerValue, wire shape is a string)', () {
      final wire = encodeFirestoreValue(42);
      expect(wire, containsPair('integerValue', '42'));
      final decoded = decodeFirestoreValue(wire);
      expect(decoded, isA<int>());
      expect(decoded, 42);
    });

    test('double stays a double (doubleValue, never integerValue)', () {
      final wire = encodeFirestoreValue(42.5);
      expect(wire, containsPair('doubleValue', 42.5));
      final decoded = decodeFirestoreValue(wire);
      expect(decoded, isA<double>());
      expect(decoded, 42.5);
    });

    test(
      'int 42 and double 42.0 are DIFFERENT wire values (type fidelity)',
      () {
        // Firestore separates integerValue from doubleValue; the differential
        // gate relies on this to make 42 vs 42.0 a real divergence.
        final intWire = encodeFirestoreValue(42);
        final doubleWire = encodeFirestoreValue(42.0);
        expect(jsonEncode(intWire) == jsonEncode(doubleWire), isFalse);
      },
    );

    test('String', () {
      final wire = encodeFirestoreValue('login-42');
      expect(wire, containsPair('stringValue', 'login-42'));
      expect(decodeFirestoreValue(wire), 'login-42');
    });

    test('List (arrayValue), nested', () {
      final value = <dynamic>[
        1,
        'two',
        true,
        <dynamic>[3.5, null],
      ];
      final decoded = decodeFirestoreValue(encodeFirestoreValue(value));
      expect(decoded, isA<List<dynamic>>());
      expect(decoded, equals(value));
    });

    test('Map (mapValue), nested', () {
      final value = <String, dynamic>{
        'id': 'u1',
        'attempts': 3,
        'meta': <String, dynamic>{'verified': true, 'ratio': 0.5},
      };
      final decoded = decodeFirestoreValue(encodeFirestoreValue(value));
      expect(decoded, isA<Map<String, dynamic>>());
      expect(decoded, equals(value));
    });

    test('unsupported type throws (fail-closed)', () {
      expect(
        () => encodeFirestoreValue(Object()),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('collection / document semantics', () {
    test('doc().set() then get() returns the document data', () async {
      final store = FakeFirebaseFirestore();
      await store.collection('login').doc('u1').set(<String, dynamic>{
        'id': 'u1',
        'email': 'a@b.c',
      });
      final snapshot = await store.collection('login').doc('u1').get();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data, <String, dynamic>{'id': 'u1', 'email': 'a@b.c'});
    });

    test('a missing document reads exists=false, data=null', () async {
      final store = FakeFirebaseFirestore();
      final snapshot = await store.collection('login').doc('nope').get();
      expect(snapshot.exists, isFalse);
      expect(snapshot.data, isNull);
    });

    test(
      'set() replaces the whole document (Firestore set semantics)',
      () async {
        final store = FakeFirebaseFirestore();
        final doc = store.collection('login').doc('u1');
        await doc.set(<String, dynamic>{
          'id': 'u1',
          'email': 'a@b.c',
          'stale': 'gone',
        });
        await doc.set(<String, dynamic>{'id': 'u1', 'email': 'z@y.x'});
        final snapshot = await doc.get();
        expect(snapshot.data, <String, dynamic>{'id': 'u1', 'email': 'z@y.x'});
      },
    );

    test('delete() removes the document and is idempotent', () async {
      final store = FakeFirebaseFirestore();
      final doc = store.collection('login').doc('u1');
      await doc.set(<String, dynamic>{'id': 'u1'});
      await doc.delete();
      expect((await doc.get()).exists, isFalse);
      // Deleting a missing document is a no-op, not an error.
      await doc.delete();
      expect((await doc.get()).exists, isFalse);
    });

    test('collection().get() lists documents in document-id order', () async {
      final store = FakeFirebaseFirestore();
      final collection = store.collection('login');
      // Inserted out of order on purpose.
      for (final id in ['u3', 'u1', 'u2']) {
        await collection.doc(id).set(<String, dynamic>{'id': id});
      }
      final snapshot = await collection.get();
      expect(snapshot.documents.map((d) => d.id).toList(), ['u1', 'u2', 'u3']);
    });

    test('collections are isolated from each other', () async {
      final store = FakeFirebaseFirestore();
      await store.collection('login').doc('u1').set(<String, dynamic>{
        'id': 'u1',
      });
      await store.collection('user').doc('u1').set(<String, dynamic>{
        'id': 'u1',
        'entity': 'user',
      });
      expect(
        (await store.collection('login').doc('u1').get()).data,
        <String, dynamic>{'id': 'u1'},
      );
      final loginDocs = await store.collection('login').get();
      expect(loginDocs.documents, hasLength(1));
    });

    test('doc() without an id allocates a fresh auto id', () {
      final store = FakeFirebaseFirestore();
      final first = store.collection('login').doc();
      final second = store.collection('login').doc();
      expect(first.id, isNotEmpty);
      expect(second.id, isNot(first.id));
    });
  });
}
