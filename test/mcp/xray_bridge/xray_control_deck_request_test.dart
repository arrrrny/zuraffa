// Spec 035 — Track 4.4: XRayControlDeckRequest / Response tests.
//
// Behavior B04.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/mcp/xray_bridge/xray_control_deck_request.dart';

void main() {
  group('XRayControlDeckRequest', () {
    test('constructor stores mockName', () {
      const r = XRayControlDeckRequest(mockName: 'Expired Product');
      expect(r.mockName, 'Expired Product');
    });

    test('toJson produces canonical shape', () {
      const r = XRayControlDeckRequest(mockName: 'A');
      final j = r.toJson();
      expect(j['mockName'], 'A');
    });

    test('fromJson round-trips', () {
      const original = XRayControlDeckRequest(mockName: 'A');
      final reconstructed = XRayControlDeckRequest.fromJson(original.toJson());
      expect(reconstructed.mockName, original.mockName);
    });

    test('fromJson throws when mockName missing', () {
      expect(
        () => XRayControlDeckRequest.fromJson({}),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws when mockName is empty string', () {
      expect(
        () => XRayControlDeckRequest.fromJson({'mockName': ''}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('XRayControlDeckResponse', () {
    test('success factory produces canonical shape', () {
      final r = XRayControlDeckResponse.success(
        mockName: 'A',
        injectedPayload: 'p1',
      );
      expect(r.statusCode, 200);
      expect(r.body['success'], isTrue);
      expect(r.body['mockName'], 'A');
      expect(r.body['injectedPayload'], 'p1');
    });

    test('unknownMock factory produces 404 + availableMockNames', () {
      final r = XRayControlDeckResponse.unknownMock(
        'unknown',
        availableMockNames: ['A', 'B'],
      );
      expect(r.statusCode, 404);
      expect(r.body['availableMockNames'], ['A', 'B']);
    });

    test('badRequest factory produces 400', () {
      final r = XRayControlDeckResponse.badRequest('missing mockName');
      expect(r.statusCode, 400);
      expect(r.body['error'], 'missing mockName');
    });

    test('releaseMode factory produces 404', () {
      final r = XRayControlDeckResponse.releaseMode();
      expect(r.statusCode, 404);
      expect(r.body['error'], contains('release'));
    });
  });
}
