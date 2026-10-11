/// Spec 968 — the world differential gate (U8, A7; #915 composes): the
/// same behaviors green against the mock world AND the real-adapter
/// harness.
library;

import 'dart:convert';
import 'dart:io' as io;

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/simulation/worlds/world_differential_gate.dart';
import 'package:zuraffa/src/simulation/worlds/world_manifest.dart';

WorldManifest _world({
  List<WorldStorm> storms = const [],
  List<WorldBehavior> behaviors = const [],
  Map<String, Map<String, dynamic>>? corpus,
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
  storms: storms,
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
  behaviors: behaviors,
  description: 'differential test fixture',
);

const flap = WorldStorm(
  name: 'flap',
  kind: 'network-flap',
  touchpoint: 'RestSync',
  fromCall: 1,
  toCall: 2,
  failure: {'type': 'http', 'status': 503},
  description: '',
);

const authExpiry = WorldStorm(
  name: 'auth-expiry',
  kind: 'auth-expiry',
  touchpoint: 'FirebaseAuth',
  fromCall: 1,
  toCall: 1,
  failure: {'type': 'auth', 'code': 'user-token-expired'},
  description: '',
);

Future<WorldDifferentialResult> _runGate(WorldManifest manifest) async {
  final dir = await io.Directory.systemTemp.createTemp('world-diff');
  addTearDown(() => dir.delete(recursive: true));
  final featureDir = p.join(dir.path, 'specs', 'spec-968');
  return const WorldDifferentialGate().run(manifest, featureDir);
}

void main() {
  group('parity (same behaviors, same outcome, both lanes)', () {
    test('green in both lanes with identical payloads → pass', () async {
      final result = await _runGate(
        _world(
          behaviors: const [
            WorldBehavior(
              id: 'pull-golden',
              driver: 'invoke',
              touchpoint: 'RestSync',
              method: 'pull',
              args: {},
              maxAttempts: 1,
            ),
          ],
        ),
      );
      expect(result.verdict, WorldDiffVerdict.pass);
      expect(result.rows.single.clazz, DiffClass.parity);
      expect(result.rows.single.payloadsEqual, isTrue);
      expect(result.rows.single.detail, contains('payloads identical'));
    });

    test('the retry behavior surviving the storm is parity (same final '
        'payload, different attempts)', () async {
      final result = await _runGate(
        _world(
          storms: const [flap],
          behaviors: const [
            WorldBehavior(
              id: 'push-retry',
              driver: 'retry-sync',
              touchpoint: 'RestSync',
              method: 'push',
              args: {},
              maxAttempts: 4,
              backoffBaseMs: 50,
              backoffFactor: 2.0,
            ),
          ],
        ),
      );
      expect(result.verdict, WorldDiffVerdict.pass);
      final row = result.rows.single;
      expect(row.clazz, DiffClass.parity);
      expect(row.detail, contains('world attempts=3'));
      expect(row.detail, contains('real attempts=1'));
    });
  });

  group('storm-proof (the declared honest red)', () {
    test('expect-red world + green real → storm-proof, gate passes', () async {
      final result = await _runGate(
        _world(
          storms: const [authExpiry],
          behaviors: const [
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
        ),
      );
      expect(result.verdict, WorldDiffVerdict.pass);
      final row = result.rows.single;
      expect(row.clazz, DiffClass.stormProof);
      expect(row.detail, contains('storm rehearsed'));
      expect(row.detail, contains('auth-user-token-expired'));
    });

    test('a blind-retry engine (declared red lands green) is DRIFT', () async {
      // No storm on signIn: the behavior lands green in the world,
      // betraying its expect: red declaration.
      final result = await _runGate(
        _world(
          behaviors: const [
            WorldBehavior(
              id: 'auth-blind',
              driver: 'invoke',
              touchpoint: 'FirebaseAuth',
              method: 'signIn',
              args: {'email': 'ada@example.com', 'password': 's3cret!'},
              maxAttempts: 1,
              expect: 'red',
            ),
          ],
        ),
      );
      expect(result.verdict, WorldDiffVerdict.drift);
      expect(result.rows.single.clazz, DiffClass.drift);
      expect(result.rows.single.detail, contains('refuses free greens'));
    });
  });

  group('drift (named, red)', () {
    test(
      'a behavior red in both lanes is drift (corpus-level fault)',
      () async {
        final result = await _runGate(
          _world(
            corpus: const {
              'RestSync': {
                'pull': {
                  'failure': {'type': 'http', 'status': 429},
                },
                'push': {
                  'fixture': {'status': 'synced'},
                },
              },
            },
            behaviors: const [
              WorldBehavior(
                id: 'pull-broken',
                driver: 'invoke',
                touchpoint: 'RestSync',
                method: 'pull',
                args: {},
                maxAttempts: 1,
              ),
            ],
          ),
        );
        expect(result.verdict, WorldDiffVerdict.drift);
        expect(result.rows.single.clazz, DiffClass.drift);
      },
    );

    test('a behavior red in the world only (unexpected) is drift', () async {
      // The flap storm outlasts the retry budget → the green-expected
      // behavior goes red in the world, stays green in the real lane.
      final result = await _runGate(
        _world(
          storms: const [
            WorldStorm(
              name: 'endless',
              kind: 'network-flap',
              touchpoint: 'RestSync',
              fromCall: 1,
              toCall: 99,
              failure: {'type': 'http', 'status': 503},
              description: '',
            ),
          ],
          behaviors: const [
            WorldBehavior(
              id: 'push-doomed',
              driver: 'retry-sync',
              touchpoint: 'RestSync',
              method: 'push',
              args: {},
              maxAttempts: 2,
              backoffBaseMs: 50,
              backoffFactor: 2.0,
            ),
          ],
        ),
      );
      expect(result.verdict, WorldDiffVerdict.drift);
      expect(result.rows.single.clazz, DiffClass.drift);
    });
  });

  group('unrehearsed storms are reported (never silently passed)', () {
    test('a declared storm that never fires is named in the result', () async {
      final result = await _runGate(
        _world(
          storms: const [
            WorldStorm(
              name: 'never-fires',
              kind: 'network-flap',
              touchpoint: 'RestSync',
              fromCall: 50,
              toCall: 60,
              failure: {'type': 'http', 'status': 503},
              description: '',
            ),
          ],
          behaviors: const [
            WorldBehavior(
              id: 'pull-once',
              driver: 'invoke',
              touchpoint: 'RestSync',
              method: 'pull',
              args: {},
              maxAttempts: 1,
            ),
          ],
        ),
      );
      expect(result.unrehearsedStorms, ['never-fires']);
      // Unrehearsed storms are a finding, not drift by themselves.
      expect(result.verdict, WorldDiffVerdict.pass);
    });
  });

  group('the committed report artifact', () {
    test('writes tdd/world-differential-report.json (world-diff.v1)', () async {
      final dir = await io.Directory.systemTemp.createTemp('world-diff');
      addTearDown(() => dir.delete(recursive: true));
      final featureDir = p.join(dir.path, 'specs', 'spec-968');
      final manifest = _world(
        storms: const [flap, authExpiry],
        behaviors: const [
          WorldBehavior(
            id: 'push-retry',
            driver: 'retry-sync',
            touchpoint: 'RestSync',
            method: 'push',
            args: {},
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
      );
      final result = await const WorldDifferentialGate().run(
        manifest,
        featureDir,
      );

      final reportFile = io.File(
        p.join(featureDir, 'tdd', 'world-differential-report.json'),
      );
      expect(reportFile.existsSync(), isTrue);
      final doc =
          jsonDecode(reportFile.readAsStringSync()) as Map<String, dynamic>;
      expect(doc['schema'], 'world-diff.v1');
      expect(doc['verdict'], 'pass');
      expect(doc['world_hash'], manifest.worldHash);
      expect(doc['parity'], 1);
      expect(doc['storm_proof'], 1);
      expect(doc['drift'], 0);
      expect(doc['unrehearsed_storms'], isEmpty);
      expect(result.verdict, WorldDiffVerdict.pass);
    });
  });
}
