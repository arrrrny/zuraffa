/// Spec 968 — the world manifest model (U1, A1).
///
/// The manifest is the committed, diffable world contract: contract
/// strings parse into method pins, documents round-trip, the canonical
/// world hash is deterministic (sorted keys — construction order never
/// lies) and byte-sensitive, and structural violations refuse with
/// `--> fix:` hints (errors-are-an-API).
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/simulation/worlds/world_manifest.dart';

WorldManifest _demoManifest() => WorldManifest(
  schema: 1,
  spec: 968,
  scenario: 'checkout-flow',
  feature: '968-simulation-worlds',
  version: 1,
  seed: 968,
  touchpoints: [
    WorldTouchpoint(
      name: 'FirebaseAuth',
      type: 'service',
      family: 'firebase-auth',
      priority: 'P1',
      contract: 'signIn(email, password) -> User, signOut() -> void',
      methods: ContractParser.parse(
        'signIn(email, password) -> User, signOut() -> void',
      ),
    ),
    WorldTouchpoint(
      name: 'RestSync',
      type: 'service',
      family: 'generic',
      priority: 'P1',
      contract: 'push(batch) -> SyncResult, pull(cursor) -> Page',
      methods: ContractParser.parse(
        'push(batch) -> SyncResult, pull(cursor) -> Page',
      ),
    ),
  ],
  latency: const {'RestSync': WorldLatencyBands.certified},
  storms: const [
    WorldStorm(
      name: 'network-flap-push',
      kind: 'network-flap',
      touchpoint: 'RestSync',
      fromCall: 1,
      toCall: 2,
      failure: {'type': 'http', 'status': 503},
      description: 'flap',
    ),
  ],
  corpus: const {
    'RestSync': {
      'push': {
        'fixture': {'status': 'synced', 'count': 2},
      },
      'pull': {
        'fixture': {'items': <dynamic>[], 'cursor': 'c-0'},
      },
    },
  },
  behaviors: const [
    WorldBehavior(
      id: 'sync-push-retry',
      driver: 'retry-sync',
      touchpoint: 'RestSync',
      method: 'push',
      args: {
        'batch': {'items': 2},
      },
      maxAttempts: 4,
      backoffBaseMs: 50,
      backoffFactor: 2.0,
    ),
    WorldBehavior(
      id: 'auth-expiry-mid-flow',
      driver: 'invoke',
      touchpoint: 'FirebaseAuth',
      method: 'signIn',
      args: {'email': 'ada@example.com', 'password': 's3cret!'},
      maxAttempts: 1,
      expect: 'red',
    ),
  ],
  description: 'demo',
);

void main() {
  group('ContractParser (the #960 declared-contract cells)', () {
    test('parses the declared auth contract into method pins', () {
      final methods = ContractParser.parse(
        'signIn(email, password) -> User, signOut() -> void',
      );
      expect(methods, hasLength(2));
      expect(methods[0].name, 'signIn');
      expect(methods[0].params, ['email', 'password']);
      expect(methods[0].returns, 'User');
      expect(methods[1].name, 'signOut');
      expect(methods[1].params, isEmpty);
      expect(methods[1].returns, 'void');
    });

    test('parses the sync contract and typed params degrade to names', () {
      final methods = ContractParser.parse(
        'push(batch: List<Item>) -> SyncResult, pull(cursor: String) -> Page',
      );
      expect(methods[0].params, ['batch']);
      expect(methods[1].params, ['cursor']);
      expect(methods[0].returns, 'SyncResult');
    });

    test('refuses an unparsable contract with the fix hint', () {
      expect(
        () => ContractParser.parse('totally opaque prose'),
        throwsA(
          isA<WorldManifestError>().having(
            (e) => e.message,
            'message',
            contains('--> fix:'),
          ),
        ),
      );
    });
  });

  group('round-trip + canonical hashing (committed, diffable)', () {
    test('document → manifest → document preserves the world hash', () {
      final manifest = _demoManifest();
      final doc =
          jsonDecode(manifest.toCanonicalJson()) as Map<String, dynamic>;
      final reparsed = WorldManifest.fromDocument(doc);
      expect(reparsed.worldHash, manifest.worldHash);
      expect(reparsed.scenario, 'checkout-flow');
      expect(reparsed.seed, 968);
      expect(reparsed.touchpoints, hasLength(2));
      expect(reparsed.storms, hasLength(1));
      expect(reparsed.behaviors, hasLength(2));
      expect(reparsed.behaviors[1].expectRed, isTrue);
    });

    test('parse(bytes) round-trips the committed file form', () {
      final manifest = _demoManifest();
      final parsed = WorldManifest.parse(
        utf8.encode(manifest.toFileContents()),
      );
      expect(parsed.worldHash, manifest.worldHash);
    });

    test('the hash is construction-order-insensitive (value semantics)', () {
      final a = _demoManifest();
      // Same values, different insertion orders in the maps.
      final b = WorldManifest.fromDocument({
        'corpus': {
          'RestSync': {
            'pull': {
              'fixture': {'items': <dynamic>[], 'cursor': 'c-0'},
            },
            'push': {
              'fixture': {'status': 'synced', 'count': 2},
            },
          },
        },
        'behaviors': [for (final x in a.behaviors) x.toJson()],
        'latency': {'RestSync': WorldLatencyBands.certified.toJson()},
        'description': 'demo',
        'seed': 968,
        'time': {'seed': 968},
        'schema': 1,
        'spec': 968,
        'scenario': 'checkout-flow',
        'feature': '968-simulation-worlds',
        'version': 1,
        'touchpoints': [
          for (final t in a.touchpoints.reversed) t.toJson(),
        ].reversed.toList(),
        'failureSchedule': {
          'storms': [for (final s in a.storms) s.toJson()],
        },
      });
      expect(
        b.worldHash,
        a.worldHash,
        reason: 'canonical hashing sorts keys — only VALUES matter',
      );
    });

    test('the hash is byte-sensitive: any mutation changes it', () {
      final a = _demoManifest();
      final doc = jsonDecode(a.toCanonicalJson()) as Map<String, dynamic>;
      ((doc['corpus'] as Map)['RestSync'] as Map)['push'] = {
        'fixture': {'status': 'synced', 'count': 3},
      };
      final mutated = WorldManifest.fromDocument(doc);
      expect(mutated.worldHash, isNot(a.worldHash));
    });

    test('the canonical JSON is key-sorted (diffable)', () {
      final text = _demoManifest().toCanonicalJson();
      final firstKeys = (jsonDecode(text) as Map<String, dynamic>).keys
          .toList();
      expect(firstKeys, equals(firstKeys.toList()..sort()));
    });
  });

  group('structural validation (errors-are-an-API)', () {
    test('refuses invalid JSON with the fix hint', () {
      expect(
        () => WorldManifest.parse(utf8.encode('{not json')),
        throwsA(
          isA<WorldManifestError>().having(
            (e) => e.message,
            'message',
            allOf(contains('not valid JSON'), contains('--> fix:')),
          ),
        ),
      );
    });

    test('refuses a non-object document', () {
      expect(
        () => WorldManifest.parse(utf8.encode('[1,2,3]')),
        throwsA(
          isA<WorldManifestError>().having(
            (e) => e.message,
            'message',
            contains('not a JSON object'),
          ),
        ),
      );
    });

    test('refuses the wrong schema version', () {
      final doc =
          jsonDecode(_demoManifest().toCanonicalJson()) as Map<String, dynamic>;
      doc['schema'] = 99;
      expect(
        () => WorldManifest.fromDocument(doc),
        throwsA(
          isA<WorldManifestError>().having(
            (e) => e.message,
            'message',
            contains('is not 1'),
          ),
        ),
      );
    });

    test('refuses a world without touchpoints', () {
      final doc =
          jsonDecode(_demoManifest().toCanonicalJson()) as Map<String, dynamic>;
      doc['touchpoints'] = <dynamic>[];
      expect(
        () => WorldManifest.fromDocument(doc),
        throwsA(
          isA<WorldManifestError>().having(
            (e) => e.message,
            'message',
            allOf(contains('no touchpoints'), contains('--> fix:')),
          ),
        ),
      );
    });

    test('refuses a touchpoint without contract methods', () {
      final doc =
          jsonDecode(_demoManifest().toCanonicalJson()) as Map<String, dynamic>;
      (doc['touchpoints'] as List)[1] = {
        'name': 'Broken',
        'type': 'service',
        'family': 'generic',
        'contract': 'n/a',
        'methods': <dynamic>[],
      };
      expect(
        () => WorldManifest.fromDocument(doc),
        throwsA(
          isA<WorldManifestError>().having(
            (e) => e.message,
            'message',
            contains('Broken'),
          ),
        ),
      );
    });

    test('refuses a behavior without a method target', () {
      final doc =
          jsonDecode(_demoManifest().toCanonicalJson()) as Map<String, dynamic>;
      (doc['behaviors'] as List)[0] = {'id': 'x', 'driver': 'invoke'};
      expect(
        () => WorldManifest.fromDocument(doc),
        throwsA(isA<WorldManifestError>()),
      );
    });

    test('storm call windows clamp toCall below fromCall', () {
      final doc =
          jsonDecode(_demoManifest().toCanonicalJson()) as Map<String, dynamic>;
      final storm =
          (doc['failureSchedule'] as Map<String, dynamic>)['storms'] as List;
      storm[0] = {
        'name': 'clamped',
        'kind': 'network-flap',
        'touchpoint': 'RestSync',
        'fromCall': 5,
        'toCall': 1,
        'failure': {'type': 'http', 'status': 500},
      };
      final manifest = WorldManifest.fromDocument(doc);
      expect(manifest.storms.single.toCall, 5);
    });
  });

  group('corpus access', () {
    test('serves declared fixtures and corpus-level failures', () {
      final manifest = _demoManifest();
      expect(manifest.corpusFixture('RestSync', 'push'), {
        'status': 'synced',
        'count': 2,
      });
      expect(manifest.corpusFixture('RestSync', 'unknown'), isNull);

      final doc =
          jsonDecode(manifest.toCanonicalJson()) as Map<String, dynamic>;
      ((doc['corpus'] as Map)['RestSync'] as Map)['pull'] = {
        'failure': {'type': 'http', 'status': 429},
      };
      final withFault = WorldManifest.fromDocument(doc);
      expect(withFault.corpusFailure('RestSync', 'pull'), {
        'type': 'http',
        'status': 429,
      });
      expect(withFault.corpusFixture('RestSync', 'pull'), isNull);
    });
  });
}
