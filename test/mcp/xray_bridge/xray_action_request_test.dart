// Spec 035 — Track 4.4: XRayActionRequest / Response tests.
//
// Behavior B03.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/mcp/xray_bridge/xray_action_request.dart';

void main() {
  group('XRayActionRequest', () {
    test('constructor with only targetNode defaults payload to null', () {
      const r = XRayActionRequest(targetNode: 'n1');
      expect(r.targetNode, 'n1');
      expect(r.payload, isNull);
    });

    test('constructor accepts explicit payload', () {
      const r = XRayActionRequest(
        targetNode: 'n1',
        payload: {'k': 'v'},
      );
      expect(r.targetNode, 'n1');
      expect(r.payload, isA<Map>());
      expect((r.payload as Map)['k'], 'v');
    });

    test('toJson produces canonical shape with payload when present', () {
      const r = XRayActionRequest(
        targetNode: 'n1',
        payload: {'k': 'v'},
      );
      final j = r.toJson();
      expect(j['targetNode'], 'n1');
      expect(j['payload'], isNotNull);
    });

    test('toJson omits payload when null', () {
      const r = XRayActionRequest(targetNode: 'n1');
      final j = r.toJson();
      expect(j['targetNode'], 'n1');
      expect(j.containsKey('payload'), isFalse);
    });

    test('fromJson round-trips', () {
      const original = XRayActionRequest(
        targetNode: 'n1',
        payload: {'k': 'v'},
      );
      final j = original.toJson();
      final reconstructed = XRayActionRequest.fromJson(j);
      expect(reconstructed.targetNode, original.targetNode);
      expect(reconstructed.payload, isNotNull);
    });

    test('fromJson throws when targetNode is missing', () {
      expect(
        () => XRayActionRequest.fromJson({}),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws when targetNode is empty string', () {
      expect(
        () => XRayActionRequest.fromJson({'targetNode': ''}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('XRayActionResponse', () {
    test('success factory produces canonical shape', () {
      final r = XRayActionResponse.success(
        nodeId: 'n1',
        actionResult: {'navigated': true},
      );
      expect(r.statusCode, 200);
      final j = r.body;
      expect(j['success'], isTrue);
      expect(j['nodeId'], 'n1');
      expect(j['actionResult'], isNotNull);
    });

    test('noBoundAction factory produces 400', () {
      final r = XRayActionResponse.noBoundAction('n1');
      expect(r.statusCode, 400);
      expect(r.body['success'], isFalse);
      expect(r.body['nodeId'], 'n1');
      expect(r.body['error'], contains('no bound action'));
    });

    test('unknownNode factory produces 404 + availableNodeIds', () {
      final r = XRayActionResponse.unknownNode(
        'unknown',
        availableNodeIds: ['n1', 'n2'],
      );
      expect(r.statusCode, 404);
      expect(r.body['availableNodeIds'], ['n1', 'n2']);
    });

    test('badRequest factory produces 400 with message', () {
      final r = XRayActionResponse.badRequest('missing targetNode');
      expect(r.statusCode, 400);
      expect(r.body['error'], 'missing targetNode');
    });

    test('releaseMode factory produces 404', () {
      final r = XRayActionResponse.releaseMode();
      expect(r.statusCode, 404);
      expect(r.body['error'], contains('release'));
    });
  });
}
