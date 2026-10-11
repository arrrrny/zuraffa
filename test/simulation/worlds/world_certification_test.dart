/// Spec 968 — world certification (U7, A2): the framework proves the
/// world's mocks satisfy the declared contracts — never self-graded.
library;

import 'dart:convert';
import 'dart:io' as io;

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/simulation/worlds/world_certification.dart';
import 'package:zuraffa/src/simulation/worlds/world_manifest.dart';

WorldManifest _world({
  Map<String, Map<String, dynamic>>? corpus,
  List<ContractMethod>? Function(String)? methodsOverride,
}) => WorldManifest(
  schema: 1,
  spec: 968,
  scenario: 'checkout-flow',
  feature: 'spec-968',
  version: 1,
  seed: 968,
  touchpoints: [
    WorldTouchpoint(
      name: 'FirebaseAuth',
      type: 'service',
      family: 'firebase-auth',
      priority: 'P1',
      contract: 'signIn(email, password) -> User, signOut() -> void',
      methods:
          methodsOverride?.call('FirebaseAuth') ??
          ContractParser.parse(
            'signIn(email, password) -> User, signOut() -> void',
          ),
    ),
    WorldTouchpoint(
      name: 'RestSync',
      type: 'service',
      family: 'generic',
      priority: 'P1',
      contract: 'push(batch) -> SyncResult, pull(cursor) -> Page',
      methods:
          methodsOverride?.call('RestSync') ??
          ContractParser.parse(
            'push(batch) -> SyncResult, pull(cursor) -> Page',
          ),
    ),
  ],
  latency: const {'RestSync': WorldLatencyBands.certified},
  storms: const [
    WorldStorm(
      name: 'auth-expiry',
      kind: 'auth-expiry',
      touchpoint: 'FirebaseAuth',
      fromCall: 1,
      toCall: 1,
      failure: {'type': 'auth', 'code': 'user-token-expired'},
      description: '',
    ),
  ],
  corpus:
      corpus ??
      const {
        'RestSync': {
          'push': {
            'fixture': {'status': 'synced', 'count': 2},
          },
          'pull': {
            'fixture': {'items': <dynamic>[], 'cursor': 'c-0'},
          },
        },
      },
  behaviors: const [],
  description: 'certification test fixture',
);

void main() {
  group('the live proof (framework-executed, never self-graded)', () {
    test('a servable world certifies every declared method', () async {
      final cert = await const WorldCertifier().certify(_world());
      expect(cert.certified, isTrue);
      expect(cert.proofs, hasLength(4));
      for (final proof in cert.proofs) {
        expect(
          proof.satisfied,
          isTrue,
          reason: '${proof.touchpoint}.${proof.method}',
        );
      }

      final authSignIn = cert.proofs.singleWhere((x) => x.method == 'signIn');
      expect(
        authSignIn.evidence,
        contains('dispatched through the certified FirebaseAuthAdapter'),
      );
      final signOut = cert.proofs.singleWhere((x) => x.method == 'signOut');
      expect(signOut.evidence, contains('void'));

      // The receipt is hash-bound to the exact world.
      expect(cert.worldHash, _world().worldHash);
      expect(cert.scenario, 'checkout-flow');
      expect(cert.at, isNotEmpty);
    });

    test('the failure schedule does not block certification (storms are '
        'behavioral, not contract violations)', () async {
      // The auth-expiry storm above fires at signIn call 1 — the exact
      // call certification makes. Certification still passes because it
      // proves servability on the storm-free view.
      final cert = await const WorldCertifier().certify(_world());
      expect(cert.certified, isTrue);
    });

    test(
      'a missing corpus fixture refuses certification with the fix hint',
      () async {
        final cert = await const WorldCertifier().certify(
          _world(
            corpus: const {
              'RestSync': {
                'pull': {
                  'fixture': {'items': <dynamic>[]},
                },
              },
            },
          ),
        );
        expect(cert.certified, isFalse);
        final push = cert.proofs.singleWhere((x) => x.method == 'push');
        expect(push.satisfied, isFalse);
        expect(push.evidence, contains('--> fix:'));
        expect(push.evidence, contains('corpus'));
      },
    );

    test('a void method that serves a value is refused', () async {
      // A GENERIC touchpoint (corpus-served): the void contract is
      // checked against what the world actually serves.
      final world = _world(
        methodsOverride: (touchpoint) => touchpoint == 'RestSync'
            ? ContractParser.parse('log(event) -> void')
            : null,
        corpus: const {
          'RestSync': {
            'log': {'fixture': 'should be null for void'},
          },
        },
      );
      // The RestSync contract now declares only log() — rebuild the
      // touchpoint methods so the world parses consistently.
      final cert = await const WorldCertifier().certify(world);
      final log = cert.proofs.singleWhere((x) => x.method == 'log');
      expect(log.satisfied, isFalse);
      expect(log.evidence, contains('declared void but served'));
    });
  });

  group('receipt persistence (committed, diffable)', () {
    test('toFileContents round-trips through loadWorldCertification', () async {
      final dir = await io.Directory.systemTemp.createTemp('world-cert');
      addTearDown(() => dir.delete(recursive: true));
      final cert = await const WorldCertifier().certify(_world());
      final file = io.File(p.join(dir.path, 'checkout-flow.cert.json'));
      await file.writeAsString(cert.toFileContents());

      final loaded = loadWorldCertification(dir.path, 'checkout-flow');
      expect(loaded, isNotNull);
      expect(loaded!.certified, isTrue);
      expect(loaded.worldHash, cert.worldHash);
      expect(loaded.proofs, hasLength(4));
      expect(loaded.scenario, 'checkout-flow');

      // The document is stable JSON (sorted, diffable).
      final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(doc['schema'], 1);
      expect(doc['spec'], 968);
    });

    test('a corrupt or missing receipt is not a certification', () async {
      final dir = await io.Directory.systemTemp.createTemp('world-cert');
      addTearDown(() => dir.delete(recursive: true));
      expect(loadWorldCertification(dir.path, 'nope'), isNull);

      io.File(
        p.join(dir.path, 'broken.cert.json'),
      ).writeAsStringSync('{broken');
      expect(loadWorldCertification(dir.path, 'broken'), isNull);
    });
  });

  group('contractDigestOf (provenance digests)', () {
    test('binds the exact declared contract text', () {
      final a = contractDigestOf(
        'signIn(email, password) -> User, signOut() -> void',
      );
      final b = contractDigestOf(
        'signIn(email, password) -> User, signOut() -> void',
      );
      final c = contractDigestOf('signIn(email, password) -> Admin');
      expect(a, b);
      expect(a, isNot(c));
      expect(a, hasLength(64));
    });
  });
}
