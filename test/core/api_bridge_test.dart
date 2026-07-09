import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/api_bridge.dart';
import 'package:zuraffa/src/core/api_endpoint.dart';
import 'package:zuraffa/src/core/failure.dart';
import 'package:zuraffa/src/core/result.dart';

void main() {
  setUp(() async {
    await ZuraffaApiBridge.resetForTesting();
  });

  tearDown(() async {
    await ZuraffaApiBridge.resetForTesting();
  });

  // ---------------------------------------------------------------------------
  // serializeResult
  // ---------------------------------------------------------------------------

  group('serializeResult', () {
    test('Success → status:success with data', () {
      final result = Result<Map<String, dynamic>, AppFailure>.success({
        'id': '1',
        'name': 'Test',
      });

      final response = ZuraffaApiBridge.serializeResult(result, (v) => v);

      final body = jsonDecode(response.result!) as Map<String, dynamic>;
      expect(body['status'], 'success');
      expect(body['data']['id'], '1');
      expect(body['data']['name'], 'Test');
    });

    test('Failure → status:error with failure block', () {
      final result = Result<String, AppFailure>.failure(
        const UnknownFailure('something broke'),
      );

      final response = ZuraffaApiBridge.serializeResult(
        result,
        (v) => {'value': v},
      );

      final body = jsonDecode(response.result!) as Map<String, dynamic>;
      expect(body['status'], 'error');
      expect(body['failure'], isA<Map>());
      expect(body['failure']['message'], 'something broke');
    });

    test('Failure contains runtimeType name in failure.type', () {
      final result = Result<String, AppFailure>.failure(
        const NotFoundFailure('item missing'),
      );

      final response = ZuraffaApiBridge.serializeResult(
        result,
        (v) => {'value': v},
      );

      final body = jsonDecode(response.result!) as Map<String, dynamic>;
      expect(body['failure']['type'], contains('NotFoundFailure'));
    });
  });

  // ---------------------------------------------------------------------------
  // errorResponse
  // ---------------------------------------------------------------------------

  group('errorResponse', () {
    test('returns status:error with type and message', () {
      final response = ZuraffaApiBridge.errorResponse('unknown', 'boom');
      final body = jsonDecode(response.result!) as Map<String, dynamic>;

      expect(body['status'], 'error');
      expect(body['failure']['type'], 'unknown');
      expect(body['failure']['message'], 'boom');
    });

    test('custom type appears verbatim', () {
      final response = ZuraffaApiBridge.errorResponse(
        'deserialization',
        'bad json',
      );
      final body = jsonDecode(response.result!) as Map<String, dynamic>;

      expect(body['failure']['type'], 'deserialization');
    });
  });

  // ---------------------------------------------------------------------------
  // registerEndpoint / _handleList (discovery)
  // ---------------------------------------------------------------------------

  group('registerEndpoint and discovery', () {
    test('registerEndpoint adds endpoint to _endpoints list', () async {
      const ep = ApiEndpoint(
        method: 'ext.zuraffa.test.doThing',
        domain: 'test',
        usecase: 'doThing',
        params: {'id': 'String'},
        returns: 'Foo',
        isStream: false,
      );

      ZuraffaApiBridge.registerEndpoint(
        endpoint: ep,
        // Minimal no-op handler — dart:developer.registerExtension is a no-op
        // in Dart test environments.
        handler: (_, _) async => ZuraffaApiBridge.errorResponse('noop', 'noop'),
      );

      // Verify the endpoint was added to the internal list.
      final endpoints = ZuraffaApiBridge.getRegisteredEndpoints();
      expect(endpoints.length, 1);
      expect(endpoints.first.method, 'ext.zuraffa.test.doThing');
      expect(endpoints.first.domain, 'test');
    });

    test(
      'after 3 endpoints, _endpoints length reflects registrations',
      () async {
        // setUp already resets. The previous test added 1 endpoint, but
        // resetForTesting runs after each test via tearDown, so we start clean.
        for (var i = 0; i < 3; i++) {
          ZuraffaApiBridge.registerEndpoint(
            endpoint: ApiEndpoint(
              method: 'ext.zuraffa.test.method$i',
              domain: 'test',
              usecase: 'method$i',
              params: const {},
              returns: 'Foo',
              isStream: false,
            ),
            handler: (_, _) async =>
                ZuraffaApiBridge.errorResponse('noop', 'noop'),
          );
        }

        final endpoints = ZuraffaApiBridge.getRegisteredEndpoints();
        expect(endpoints.length, 3);
        expect(endpoints[0].method, 'ext.zuraffa.test.method0');
        expect(endpoints[1].method, 'ext.zuraffa.test.method1');
        expect(endpoints[2].method, 'ext.zuraffa.test.method2');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Stream lifecycle: subscribe → poll → cancel
  // ---------------------------------------------------------------------------

  group('stream lifecycle', () {
    test('registerStreamSubscription stores subscription', () async {
      final controller = StreamController<int>.broadcast();
      final sub = controller.stream.listen((_) {});

      final id = ZuraffaApiBridge.registerStreamSubscription(
        'test-id-1',
        sub,
        (_) {},
      );
      expect(id, 'test-id-1');

      await controller.close();
    });

    test('pollStream returns pending before first emission', () async {
      final controller = StreamController<int>.broadcast();
      final sub = controller.stream.listen((_) {});

      ZuraffaApiBridge.registerStreamSubscription('sub-1', sub, (_) {});

      final response = await ZuraffaApiBridge.handlePollStream(
        'ext.zuraffa._pollStream',
        {'subscriptionId': 'sub-1'},
      );

      final body = jsonDecode(response.result!) as Map<String, dynamic>;
      expect(body['status'], 'pending');

      await controller.close();
    });

    test('pollStream returns latest value after emission', () async {
      final controller = StreamController<int>.broadcast();
      ZuraffaApiBridge.registerStreamSubscription(
        'sub-2',
        controller.stream.listen((v) {
          ZuraffaApiBridge.updateStreamValue('sub-2', {'value': v});
        }),
        (_) {},
      );

      controller.add(42);
      await Future.microtask(() {});

      final response = await ZuraffaApiBridge.handlePollStream(
        'ext.zuraffa._pollStream',
        {'subscriptionId': 'sub-2'},
      );

      final body = jsonDecode(response.result!) as Map<String, dynamic>;
      // _handlePollStream returns the stored value as-is (pass-through).
      // The listener stores {'value': v}, so poll returns {'value': 42}.
      expect(body['value'], 42);

      await controller.close();
    });

    test('cancelStream removes subscription from registry', () async {
      final controller = StreamController<int>.broadcast();
      ZuraffaApiBridge.registerStreamSubscription(
        'sub-3',
        controller.stream.listen((_) {}),
        (_) {},
      );

      final cancelResponse = await ZuraffaApiBridge.handleCancelStream(
        'ext.zuraffa._cancelStream',
        {'subscriptionId': 'sub-3'},
      );

      final body = jsonDecode(cancelResponse.result!) as Map<String, dynamic>;
      expect(body['status'], 'cancelled');

      // Subsequent poll returns notFound
      final pollAfter = await ZuraffaApiBridge.handlePollStream(
        'ext.zuraffa._pollStream',
        {'subscriptionId': 'sub-3'},
      );
      final pollBody = jsonDecode(pollAfter.result!) as Map<String, dynamic>;
      expect(pollBody['status'], 'error');
      expect(pollBody['failure']['type'], 'notFound');

      await controller.close();
    });

    test('two concurrent streams with different IDs are independent', () async {
      final c1 = StreamController<int>.broadcast();
      final c2 = StreamController<int>.broadcast();

      ZuraffaApiBridge.registerStreamSubscription(
        'stream-A',
        c1.stream.listen((v) {
          ZuraffaApiBridge.updateStreamValue('stream-A', {'v': v});
        }),
        (_) {},
      );
      ZuraffaApiBridge.registerStreamSubscription(
        'stream-B',
        c2.stream.listen((v) {
          ZuraffaApiBridge.updateStreamValue('stream-B', {'v': v});
        }),
        (_) {},
      );

      c1.add(1);
      c2.add(2);
      await Future.microtask(() {});

      final respA = await ZuraffaApiBridge.handlePollStream(
        'ext.zuraffa._pollStream',
        {'subscriptionId': 'stream-A'},
      );
      final respB = await ZuraffaApiBridge.handlePollStream(
        'ext.zuraffa._pollStream',
        {'subscriptionId': 'stream-B'},
      );

      final bodyA = jsonDecode(respA.result!) as Map<String, dynamic>;
      final bodyB = jsonDecode(respB.result!) as Map<String, dynamic>;

      expect(bodyA['v'], 1);
      expect(bodyB['v'], 2);

      await c1.close();
      await c2.close();
    });

    test('pollStream with missing subscriptionId returns badRequest', () async {
      final response = await ZuraffaApiBridge.handlePollStream(
        'ext.zuraffa._pollStream',
        {},
      );
      final body = jsonDecode(response.result!) as Map<String, dynamic>;
      expect(body['status'], 'error');
      expect(body['failure']['type'], 'badRequest');
    });

    test(
      'cancelStream with missing subscriptionId returns badRequest',
      () async {
        final response = await ZuraffaApiBridge.handleCancelStream(
          'ext.zuraffa._cancelStream',
          {},
        );
        final body = jsonDecode(response.result!) as Map<String, dynamic>;
        expect(body['status'], 'error');
        expect(body['failure']['type'], 'badRequest');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // generateSubscriptionId
  // ---------------------------------------------------------------------------

  group('generateSubscriptionId', () {
    test('generates non-empty unique UUIDs', () {
      final id1 = ZuraffaApiBridge.generateSubscriptionId();
      final id2 = ZuraffaApiBridge.generateSubscriptionId();
      expect(id1, isNotEmpty);
      expect(id2, isNotEmpty);
      expect(id1, isNot(id2));
    });
  });
}
