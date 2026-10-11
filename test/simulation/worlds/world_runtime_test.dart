/// Spec 968 — the world runtime (U5, A4): the simulated reality.
///
/// Invocation applies the world's semantics in order — latency (virtual
/// clock advance, never wall time), failure schedule (typed simulated
/// failures + the partial-write marker), then the golden corpus (or the
/// certified adapter for auth-family touchpoints). The play ledger
/// records everything; the run digest is deterministic.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/simulation/simulation_adapters.dart';
import 'package:zuraffa/src/simulation/worlds/failure_schedule.dart';
import 'package:zuraffa/src/simulation/worlds/world_manifest.dart';
import 'package:zuraffa/src/simulation/worlds/world_runtime.dart';

WorldManifest _manifest({
  List<WorldStorm> storms = const [],
  Map<String, Map<String, dynamic>>? corpus,
  List<WorldBehavior> behaviors = const [],
  int seed = 968,
}) => WorldManifest(
  schema: 1,
  spec: 968,
  scenario: 'checkout-flow',
  feature: 'spec-968',
  version: 1,
  seed: seed,
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
        'FirebaseAuth': {
          'signIn': {
            'fixture': {
              'uid': 'u-ada-001',
              'email': 'ada@example.com',
              'displayName': 'Ada Lovelace',
            },
          },
          'signOut': {'fixture': null},
        },
      },
  behaviors: behaviors,
  description: 'runtime test fixture',
);

void main() {
  group('invocation basics', () {
    test('serves the golden corpus fixture for declared methods', () async {
      final runtime = WorldRuntime(_manifest());
      final result = await runtime.invoke('b1', 'RestSync', 'push');
      expect(result, {'status': 'synced', 'count': 2});
      expect(
        result,
        isNot(same(_manifest().corpusFixture('RestSync', 'push'))),
      );
    });

    test(
      'served fixtures are deep copies (invocations cannot poison the corpus)',
      () async {
        final runtime = WorldRuntime(_manifest());
        final a =
            (await runtime.invoke('b1', 'RestSync', 'push'))
                as Map<String, dynamic>;
        a['poisoned'] = true;
        final b =
            (await runtime.invoke('b2', 'RestSync', 'push'))
                as Map<String, dynamic>;
        expect(b.containsKey('poisoned'), isFalse);
      },
    );

    test(
      'refuses unknown touchpoints and methods (never a silent no-op)',
      () async {
        final runtime = WorldRuntime(_manifest());
        await expectLater(
          runtime.invoke('b1', 'Nonexistent', 'push'),
          throwsA(
            isA<WorldProgramError>().having(
              (e) => e.message,
              'message',
              allOf(contains('unknown touchpoint'), contains('--> fix:')),
            ),
          ),
        );
        await expectLater(
          runtime.invoke('b1', 'RestSync', 'undeclared'),
          throwsA(
            isA<WorldProgramError>().having(
              (e) => e.message,
              'message',
              contains('declared contract does not pin'),
            ),
          ),
        );
      },
    );

    test(
      'latency advances the VIRTUAL clock and never sleeps wall time',
      () async {
        final runtime = WorldRuntime(_manifest());
        final wall = Stopwatch()..start();
        await runtime.invoke('b1', 'RestSync', 'pull');
        await runtime.invoke('b2', 'RestSync', 'pull');
        await runtime.invoke('b3', 'RestSync', 'pull');
        await runtime.invoke('b4', 'RestSync', 'pull');
        wall.stop();
        // Four draws: at least the fast band each (4th call is the slow
        // band under certified defaults — 120..400ms of virtual time).
        expect(runtime.virtualElapsedMs, greaterThan(0));
        expect(
          wall.elapsedMilliseconds,
          lessThan(500),
          reason: 'latency is virtual — the runtime never sleeps',
        );
      },
    );

    test(
      'the play ledger records every invocation with its evidence',
      () async {
        final runtime = WorldRuntime(_manifest());
        await runtime.invoke('b1', 'RestSync', 'push');
        await runtime.invoke('b1', 'RestSync', 'push');
        expect(runtime.plays, hasLength(2));
        expect(runtime.plays[0].call, 1);
        expect(runtime.plays[1].call, 2);
        expect(runtime.plays[0].behavior, 'b1');
        expect(runtime.plays[0].outcome, 'ok');
        expect(runtime.plays[0].touchpoint, 'RestSync');
        expect(runtime.plays[0].method, 'push');
        expect(runtime.plays[0].band, anyOf('fast', 'slow', 'timeout'));
      },
    );
  });

  group('failure storms fire exactly where declared', () {
    test(
      'the network flap throws the typed HTTP failure over the window',
      () async {
        final runtime = WorldRuntime(
          _manifest(
            storms: const [
              WorldStorm(
                name: 'flap',
                kind: 'network-flap',
                touchpoint: 'RestSync',
                fromCall: 2,
                toCall: 3,
                failure: {'type': 'http', 'status': 503},
                description: '',
              ),
            ],
          ),
        );
        // Call 1: clean.
        expect(await runtime.invoke('b', 'RestSync', 'push'), isNotNull);
        // Calls 2..3: flap.
        await expectLater(
          runtime.invoke('b', 'RestSync', 'push'),
          throwsA(
            isA<SimulatedHttpException>().having(
              (e) => e.statusCode,
              'status',
              503,
            ),
          ),
        );
        await expectLater(
          runtime.invoke('b', 'RestSync', 'push'),
          throwsA(isA<SimulatedHttpException>()),
        );
        // Call 4: recovered.
        expect(await runtime.invoke('b', 'RestSync', 'push'), isNotNull);
        // The ledger recorded the failures.
        expect(
          runtime.plays.where((p) => p.outcome == 'failure'),
          hasLength(2),
        );
        expect(runtime.plays[1].detail, contains('storm flap'));
      },
    );

    test(
      'the auth-expiry storm throws the typed auth failure mid-flow',
      () async {
        final runtime = WorldRuntime(
          _manifest(
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
          ),
        );
        await expectLater(
          runtime.invoke('b', 'FirebaseAuth', 'signIn', {
            'email': 'ada@example.com',
            'password': 's3cret!',
          }),
          throwsA(
            isA<SimulatedAuthException>().having(
              (e) => e.code,
              'code',
              'user-token-expired',
            ),
          ),
        );
      },
    );

    test(
      'the partial-write storm returns the marked half-written record',
      () async {
        final runtime = WorldRuntime(
          _manifest(
            storms: const [
              WorldStorm(
                name: 'partial',
                kind: 'partial-write',
                touchpoint: 'RestSync',
                fromCall: 1,
                toCall: 1,
                failure: {'type': 'partial'},
                description: '',
              ),
            ],
          ),
        );
        final result = await runtime.invoke('b', 'RestSync', 'push');
        expect(result, isA<Map>());
        expect((result as Map)[kPartialWriteMarker], isTrue);
        expect(
          result['status'],
          'synced',
          reason: 'the payload itself is the real fixture, half-marked',
        );
        expect(runtime.plays.single.outcome, 'partial');
      },
    );

    test('the real binding injects NO world semantics', () async {
      final runtime = WorldRuntime(
        _manifest(
          storms: const [
            WorldStorm(
              name: 'flap',
              kind: 'network-flap',
              touchpoint: 'RestSync',
              fromCall: 1,
              toCall: 9,
              failure: {'type': 'http', 'status': 503},
              description: '',
            ),
          ],
        ),
        binding: WorldBinding.real,
      );
      // Even inside the declared storm window: the real-adapter harness
      // serves the fixture directly.
      final result = await runtime.invoke('b', 'RestSync', 'push');
      expect(result, {'status': 'synced', 'count': 2});
      expect(
        runtime.virtualElapsedMs,
        0,
        reason: 'the real binding advances no virtual time',
      );
      expect(runtime.plays.single.band, 'none');
    });
  });

  group('certified-adapter composition (auth family)', () {
    test(
      'signIn dispatches through the #832 certified FirebaseAuthAdapter',
      () async {
        final runtime = WorldRuntime(_manifest());
        final user = await runtime.invoke('b', 'FirebaseAuth', 'signIn', {
          'email': 'ada@example.com',
          'password': 's3cret!',
        });
        expect(user, {
          'uid': 'u-ada-001',
          'email': 'ada@example.com',
          'displayName': 'Ada Lovelace',
        });
      },
    );

    test('a wrong credential surfaces the certified scripted error', () async {
      final runtime = WorldRuntime(_manifest());
      await expectLater(
        runtime.invoke('b', 'FirebaseAuth', 'signIn', {
          'email': 'ada@example.com',
          'password': 'wrong',
        }),
        throwsA(
          isA<SimulatedAuthException>().having(
            (e) => e.code,
            'code',
            'wrong-password',
          ),
        ),
      );
    });

    test('the corpus-level scripted fault fires in both bindings', () async {
      final manifest = _manifest(
        corpus: const {
          'RestSync': {
            'push': {
              'failure': {'type': 'http', 'status': 429},
            },
            'pull': {'fixture': null},
          },
          'FirebaseAuth': {
            'signIn': {'fixture': null},
            'signOut': {'fixture': null},
          },
        },
      );
      await expectLater(
        WorldRuntime(manifest).invoke('b', 'RestSync', 'push'),
        throwsA(
          isA<SimulatedHttpException>().having(
            (e) => e.statusCode,
            'status',
            429,
          ),
        ),
      );
      await expectLater(
        WorldRuntime(
          manifest,
          binding: WorldBinding.real,
        ).invoke('b', 'RestSync', 'push'),
        throwsA(isA<SimulatedHttpException>()),
      );
    });
  });

  group('executeScenario (the behavior program)', () {
    WorldManifest programManifest() => _manifest(
      storms: const [
        WorldStorm(
          name: 'flap',
          kind: 'network-flap',
          touchpoint: 'RestSync',
          fromCall: 1,
          toCall: 2,
          failure: {'type': 'http', 'status': 503},
          description: '',
        ),
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
      behaviors: const [
        WorldBehavior(
          id: 'sync-push-retry-sync',
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

    test(
      'the retry behavior survives the storm; the auth behavior lands its declared red',
      () async {
        final runtime = WorldRuntime(programManifest());
        final results = await runtime.executeScenario();

        expect(results, hasLength(2));
        final retry = results[0];
        expect(retry.passed, isTrue);
        expect(retry.succeeded, isTrue);
        expect(retry.attempts, 3, reason: 'calls 1..2 flap, call 3 succeeds');
        expect(retry.failureLedger, ['http-503', 'http-503']);

        final auth = results[1];
        expect(
          auth.passed,
          isTrue,
          reason: 'expect: red landed red — matched its declaration',
        );
        expect(auth.succeeded, isFalse);
        expect(auth.expectedRed, isTrue);
        expect(auth.failureLedger, ['auth-user-token-expired']);
      },
    );

    test('the run digest is deterministic for the same world + seed', () async {
      final a = await WorldRuntime(programManifest()).executeScenario();
      expect(a, isNotEmpty); // run the program so the ledger fills.
      final runtimeA = WorldRuntime(programManifest());
      await runtimeA.executeScenario();
      final runtimeB = WorldRuntime(programManifest());
      await runtimeB.executeScenario();
      expect(runtimeA.runDigest, runtimeB.runDigest);
    });

    test('the run digest differs when the world differs', () async {
      final runtimeA = WorldRuntime(programManifest());
      await runtimeA.executeScenario();
      final runtimeB = WorldRuntime(_manifest());
      await runtimeB.executeScenario();
      expect(runtimeA.runDigest, isNot(runtimeB.runDigest));
    });

    test('the run digest differs when the binding differs', () async {
      final world = WorldRuntime(programManifest());
      await world.executeScenario();
      final real = WorldRuntime(programManifest(), binding: WorldBinding.real);
      await real.executeScenario();
      expect(world.runDigest, isNot(real.runDigest));
    });

    test(
      'a blind-retry engine fails the declared honest-red behavior',
      () async {
        // A behavior declared expect: red that lands green must FAIL its
        // expectation (the world refuses free greens in both directions).
        final manifest = _manifest(
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
        );
        final results = await WorldRuntime(manifest).executeScenario();
        expect(
          results.single.passed,
          isFalse,
          reason: 'signIn succeeded but the behavior declared red',
        );
        expect(results.single.succeeded, isTrue);
      },
    );
  });
}
