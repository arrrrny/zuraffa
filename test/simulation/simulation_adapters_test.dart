/// Bug #832 — external-service simulation adapters (VISION §9).
///
/// The five certified adapter families (FirebaseAuth, Vendure, Rest,
/// AdMob, Otel) must behave deterministically against their fixture
/// worlds with NO real network. The network-isolation guard is installed
/// for the whole suite so every adapter interaction here is certified
/// socket-free: if any adapter ever opened a real socket, this suite
/// would fail with a NetworkIsolationViolation instead of passing.
library;

import 'dart:async';
import 'dart:convert';

import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;
import 'package:test/test.dart';
import 'package:zuraffa/src/simulation/network_isolation_guard.dart';
import 'package:zuraffa/src/simulation/simulation_adapters.dart';

void main() {
  setUpAll(() {
    // Certify the simulation: any real socket from any adapter test below
    // becomes an immediate, loud failure.
    NetworkIsolationGuard.install();
  });

  tearDownAll(() {
    NetworkIsolationGuard.uninstall();
  });

  group('FirebaseAuthAdapter (scriptable auth states)', () {
    test(
      'signIn with certified credentials flips signed-out to signed-in',
      () async {
        final auth = FirebaseAuthAdapter(
          world: const {
            'initialUser': null,
            'users': [
              {
                'email': 'ada@example.com',
                'password': 's3cret!',
                'uid': 'u-ada-001',
                'displayName': 'Ada',
              },
            ],
            'scriptedErrors': <Map<String, dynamic>>[],
            'deletionRequiresRecentLogin': false,
          },
        );
        expect(auth.isSignedIn, isFalse);
        expect(auth.currentUser, isNull);
        final user = await auth.signIn(
          email: 'ada@example.com',
          password: 's3cret!',
        );
        expect(user.uid, 'u-ada-001');
        expect(user.email, 'ada@example.com');
        expect(auth.isSignedIn, isTrue);
        expect(auth.currentUser!.uid, 'u-ada-001');
      },
    );

    test('scripted credential errors surface deterministic codes', () async {
      final auth = FirebaseAuthAdapter(
        world: const {
          'initialUser': null,
          'users': [
            {
              'email': 'ada@example.com',
              'password': 's3cret!',
              'uid': 'u-ada-001',
              'displayName': 'Ada',
            },
            {
              'email': 'disabled@example.com',
              'password': 'whatever',
              'uid': 'u-disabled-001',
              'displayName': 'Locked',
            },
          ],
          'scriptedErrors': [
            {'email': 'disabled@example.com', 'code': 'user-disabled'},
          ],
          'deletionRequiresRecentLogin': false,
        },
      );

      // Unknown email -> user-not-found.
      await expectLater(
        auth.signIn(email: 'ghost@example.com', password: 'x'),
        throwsA(
          isA<SimulatedAuthException>().having(
            (e) => e.code,
            'code',
            'user-not-found',
          ),
        ),
      );
      // Known email, wrong password -> wrong-password.
      await expectLater(
        auth.signIn(email: 'ada@example.com', password: 'nope'),
        throwsA(
          isA<SimulatedAuthException>().having(
            (e) => e.code,
            'code',
            'wrong-password',
          ),
        ),
      );
      // Scripted error surface -> exact scripted code.
      await expectLater(
        auth.signIn(email: 'disabled@example.com', password: 'whatever'),
        throwsA(
          isA<SimulatedAuthException>().having(
            (e) => e.code,
            'code',
            'user-disabled',
          ),
        ),
      );
      // Still signed out after every failure.
      expect(auth.isSignedIn, isFalse);
    });

    test('register, duplicate register, signOut and deletion flows', () async {
      final auth = FirebaseAuthAdapter(
        world: const {
          'initialUser': null,
          'users': [
            {
              'email': 'ada@example.com',
              'password': 's3cret!',
              'uid': 'u-ada-001',
              'displayName': 'Ada',
            },
          ],
          'scriptedErrors': <Map<String, dynamic>>[],
          'deletionRequiresRecentLogin': false,
        },
      );

      await auth.register(email: 'new@example.com', password: 'fresh-1');
      expect(auth.isSignedIn, isTrue);
      await expectLater(
        auth.register(email: 'new@example.com', password: 'again-2'),
        throwsA(
          isA<SimulatedAuthException>().having(
            (e) => e.code,
            'code',
            'email-already-in-use',
          ),
        ),
      );
      await auth.signOut();
      expect(auth.isSignedIn, isFalse);

      // Deletion flow: sign back in, delete, verify the account is gone.
      await auth.signIn(email: 'new@example.com', password: 'fresh-1');
      await auth.deleteAccount();
      expect(auth.isSignedIn, isFalse);
      await expectLater(
        auth.signIn(email: 'new@example.com', password: 'fresh-1'),
        throwsA(
          isA<SimulatedAuthException>().having(
            (e) => e.code,
            'code',
            'user-not-found',
          ),
        ),
      );
    });

    test('scriptable requires-recent-login deletion guard', () async {
      final auth = FirebaseAuthAdapter(
        world: const {
          'initialUser': null,
          'users': [
            {
              'email': 'ada@example.com',
              'password': 's3cret!',
              'uid': 'u-ada-001',
              'displayName': 'Ada',
            },
          ],
          'scriptedErrors': <Map<String, dynamic>>[],
          'deletionRequiresRecentLogin': true,
        },
      );
      await auth.signIn(email: 'ada@example.com', password: 's3cret!');
      await expectLater(
        auth.deleteAccount(),
        throwsA(
          isA<SimulatedAuthException>().having(
            (e) => e.code,
            'code',
            'requires-recent-login',
          ),
        ),
      );
      // The user survives the refused deletion.
      expect(auth.isSignedIn, isTrue);
      expect(auth.currentUser!.uid, 'u-ada-001');
    });
  });

  group('VendureAdapter (GraphQL golden fixtures)', () {
    const world = {
      'goldenQueries': {
        'product': {
          'data': {
            'product': {'id': '1', 'name': 'Kayak'},
          },
          'errors': null,
        },
      },
      'goldenMutations': {
        'addItemToOrder': {
          'data': {
            'addItemToOrder': {'id': '9'},
          },
          'errors': null,
        },
      },
      'scriptedErrors': {
        'search': [
          {'message': 'Insufficient stock', 'code': 'STOCK_ERROR'},
        ],
      },
      'latencyMs': 0,
    };

    test('named queries replay their golden response verbatim', () async {
      final vendure = VendureAdapter(world: world);
      final response = await vendure.query('query product { product { id } }');
      expect(
        jsonEncode(response),
        jsonEncode({
          'data': {
            'product': {'id': '1', 'name': 'Kayak'},
          },
          'errors': null,
        }),
      );
      // Deterministic: identical call, identical bytes.
      final again = await vendure.query('query product { product { id } }');
      expect(jsonEncode(again), jsonEncode(response));
    });

    test('mutations replay golden responses', () async {
      final vendure = VendureAdapter(world: world);
      final response = await vendure.mutation(
        'mutation addItemToOrder(\$id: ID!) { addItemToOrder(id: \$id) { id } }',
        variables: {'id': '9'},
      );
      expect(response['data']['addItemToOrder']['id'], '9');
    });

    test(
      'unknown operations refuse with a deterministic error surface',
      () async {
        final vendure = VendureAdapter(world: world);
        await expectLater(
          vendure.query('query notRecorded { notRecorded { id } }'),
          throwsA(isA<SimulatedGraphQLError>()),
        );
      },
    );

    test('scripted GraphQL errors replay the recorded payload', () async {
      final vendure = VendureAdapter(world: world);
      await expectLater(
        vendure.query('query search { search { items { id } } }'),
        throwsA(
          isA<SimulatedGraphQLError>().having(
            (e) => e.errors.first['code'],
            'code',
            'STOCK_ERROR',
          ),
        ),
      );
    });
  });

  group('RestAdapter (JSON fixtures + latency/fault injection)', () {
    const world = {
      'fixtures': {
        'GET /v1/quote/USD-TRY': {
          'status': 200,
          'body': {'symbol': 'USD-TRY', 'price': 41.2},
        },
        'GET /v1/search?q=kayak': {
          'status': 200,
          'body': {
            'results': ['Kayak 1'],
          },
        },
        'POST /v1/lists': {
          'status': 201,
          'body': {'id': 'list-1'},
        },
      },
      'scriptedFaults': {'GET /v1/unstable': 500},
      'latencyMs': 0,
    };

    test('recorded fixtures replay for market-data paths', () async {
      final rest = RestAdapter(world: world);
      final quote = await rest.get('/v1/quote/USD-TRY');
      expect(quote['symbol'], 'USD-TRY');
      expect(quote['price'], 41.2);
    });

    test('query strings match base-path fixtures', () async {
      final rest = RestAdapter(world: world);
      final results = await rest.get('/v1/search', query: {'q': 'kayak'});
      expect(results['results'], ['Kayak 1']);
    });

    test('post/put/delete hit the same fixture contract', () async {
      final rest = RestAdapter(world: world);
      final created = await rest.post('/v1/lists', body: {'name': 'x'});
      expect(created['id'], 'list-1');
      expect(await rest.put('/v1/lists', body: {'name': 'y'}), created);
      expect(await rest.delete('/v1/lists'), created);
    });

    test('scripted faults raise deterministic HTTP failures', () async {
      final rest = RestAdapter(world: world);
      await expectLater(
        rest.get('/v1/unstable'),
        throwsA(
          isA<SimulatedHttpException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
    });

    test('unknown paths 404 deterministically', () async {
      final rest = RestAdapter(world: world);
      await expectLater(
        rest.get('/v1/never-recorded'),
        throwsA(
          isA<SimulatedHttpException>().having(
            (e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });

    test('latency injection delays responses without jitter', () async {
      final rest = RestAdapter(
        world: const {
          'fixtures': {
            'GET /v1/quote/USD-TRY': {
              'status': 200,
              'body': {'price': 41.2},
            },
          },
          'scriptedFaults': <String, int>{},
          'latencyMs': 15,
        },
      );
      final sw = Stopwatch()..start();
      await rest.get('/v1/quote/USD-TRY');
      sw.stop();
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(10));
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });

  group('AdMobAdapter (load/show/fail callbacks)', () {
    test('load fires onAdLoaded and show fires shown/dismissed', () async {
      final admob = AdMobAdapter(
        world: const {
          'scriptedLoadFailure': null,
          'scriptedShowFailure': null,
          'latencyMs': 0,
        },
      );
      final events = <String>[];
      await admob.load(
        callbacks: AdCallbacks(onAdLoaded: () => events.add('loaded')),
      );
      expect(admob.state, AdLoadState.loaded);
      await admob.show(
        callbacks: AdCallbacks(
          onAdShown: () => events.add('shown'),
          onAdDismissed: () => events.add('dismissed'),
        ),
      );
      expect(events, ['loaded', 'shown', 'dismissed']);
      expect(admob.state, AdLoadState.dismissed);
    });

    test(
      'scripted failures route to onAdFailed with the scripted code',
      () async {
        final admob = AdMobAdapter(
          world: const {
            'scriptedLoadFailure': null,
            'scriptedShowFailure': null,
            'latencyMs': 0,
          },
        );
        admob.scriptLoadFailure('no-fill');
        final events = <String>[];
        await admob.load(
          callbacks: AdCallbacks(
            onAdLoaded: () => events.add('loaded'),
            onAdFailed: (code) => events.add('failed:$code'),
          ),
        );
        expect(events, ['failed:no-fill']);
        expect(admob.state, AdLoadState.failed);

        admob.clearScripts();
        admob.scriptShowFailure('ad-not-ready');
        await admob.load(
          callbacks: AdCallbacks(onAdLoaded: () => events.add('loaded')),
        );
        expect(events.last, 'loaded');
        await admob.show(
          callbacks: AdCallbacks(
            onAdFailed: (code) => events.add('show-failed:$code'),
          ),
        );
        expect(events.last, 'show-failed:ad-not-ready');
      },
    );
  });

  group('OtelAdapter (capture-and-assert exporter)', () {
    test('captures spans produced through the real SDK pipeline', () async {
      final otel = OtelAdapter();
      final provider = otel_sdk.TracerProviderBase(
        processors: [otel_sdk.SimpleSpanProcessor(otel)],
      );
      final tracer = provider.getTracer('simulation-test');
      final span = tracer.startSpan(
        'usecase.PlaceOrder',
        attributes: [otel_api.Attribute.fromString('order.id', 'o-42')],
      );
      span.end();

      // Give the SimpleSpanProcessor a microtask to export.
      await Future<void>.delayed(Duration.zero);

      expect(otel.spanNames, contains('usecase.PlaceOrder'));
      final record = otel.byName('usecase.PlaceOrder');
      expect(record, isNotNull);
      expect(record!.attributes['order.id'], 'o-42');
      expect(otel.hasSpan('usecase.PlaceOrder'), isTrue);
      expect(otel.hasSpan('usecase.NeverRan'), isFalse);
    });

    test('capture-and-assert: ended spans report their status', () async {
      final otel = OtelAdapter();
      final provider = otel_sdk.TracerProviderBase(
        processors: [otel_sdk.SimpleSpanProcessor(otel)],
      );
      final tracer = provider.getTracer('simulation-test');
      final ok = tracer.startSpan('usecase.Healthy')..end();
      expect(ok, isNotNull);
      final failing = tracer.startSpan('usecase.Broken');
      failing.setStatus(otel_api.StatusCode.error, 'boom');
      failing.end();
      await Future<void>.delayed(Duration.zero);

      final healthy = otel.byName('usecase.Healthy');
      final broken = otel.byName('usecase.Broken');
      expect(healthy, isNotNull);
      expect(broken, isNotNull);
      expect(broken!.statusCode, otel_api.StatusCode.error);
    });

    test('implements the production SpanExporter interface', () {
      final otel = OtelAdapter();
      // Same production interface the OTLP collector exporter implements.
      expect(otel, isA<otel_sdk.SpanExporter>());
      otel.forceFlush();
      otel.shutdown();
      expect(otel.isShutdown, isTrue);
    });
  });
}
