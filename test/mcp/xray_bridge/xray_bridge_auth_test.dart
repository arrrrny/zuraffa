// Spec 035 — Track 4.4: XRayBridgeAuth helpers tests.
//
// Behaviors B17, B18.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/mcp/xray_bridge/xray_bridge_auth.dart';

void main() {
  group('XRayBridgeAuth.isLocalhost', () {
    test('B17 — 127.0.0.1 is localhost', () {
      expect(XRayBridgeAuth.isLocalhost('127.0.0.1'), isTrue);
    });

    test('B17 — ::1 is localhost', () {
      expect(XRayBridgeAuth.isLocalhost('::1'), isTrue);
    });

    test('B17 — localhost hostname is localhost', () {
      expect(XRayBridgeAuth.isLocalhost('localhost'), isTrue);
    });

    test('B17 — 192.168.1.5 is NOT localhost', () {
      expect(XRayBridgeAuth.isLocalhost('192.168.1.5'), isFalse);
    });

    test('B17 — 10.0.0.1 is NOT localhost', () {
      expect(XRayBridgeAuth.isLocalhost('10.0.0.1'), isFalse);
    });

    test('B17 — empty string is NOT localhost', () {
      expect(XRayBridgeAuth.isLocalhost(''), isFalse);
    });

    test('B17 — 127.0.0.1:8080 (with port) is localhost', () {
      expect(XRayBridgeAuth.isLocalhost('127.0.0.1:8080'), isTrue);
    });

    test('B17 — ::1:8080 is localhost', () {
      expect(XRayBridgeAuth.isLocalhost('[::1]:8080'), isTrue);
    });
  });

  group('XRayBridgeAuth.validateBearerToken', () {
    test('B18 — matching token returns true', () {
      expect(XRayBridgeAuth.validateBearerToken('abc', 'abc'), isTrue);
    });

    test('B18 — mismatched token returns false', () {
      expect(XRayBridgeAuth.validateBearerToken('abc', 'xyz'), isFalse);
    });

    test('B18 — empty received returns false', () {
      expect(XRayBridgeAuth.validateBearerToken('', 'abc'), isFalse);
    });

    test('B18 — null received returns false when expected set', () {
      expect(XRayBridgeAuth.validateBearerToken(null, 'abc'), isFalse);
    });

    test('B18 — null expected returns false (no auth configured)', () {
      expect(XRayBridgeAuth.validateBearerToken('abc', null), isFalse);
    });

    test('B18 — null received AND null expected returns false', () {
      expect(XRayBridgeAuth.validateBearerToken(null, null), isFalse);
    });

    test('B18 — different-length tokens return false', () {
      expect(XRayBridgeAuth.validateBearerToken('abc', 'abcd'), isFalse);
    });

    test('B18 — constant-time comparison: same length but different content',
        () {
      // The result must be false; we cannot test timing directly in unit
      // tests, but the implementation must NOT short-circuit on first
      // byte mismatch (verified by code review).
      expect(
        XRayBridgeAuth.validateBearerToken('xyz', 'abc'),
        isFalse,
      );
    });

    test(
        'validateBearerTokenWithHeader strips "Bearer " prefix from received',
        () {
      expect(
        XRayBridgeAuth.validateBearerTokenWithHeader('Bearer abc', 'abc'),
        isTrue,
      );
      expect(
        XRayBridgeAuth.validateBearerTokenWithHeader('abc', 'abc'),
        isTrue,
      );
      expect(
        XRayBridgeAuth.validateBearerTokenWithHeader('Bearer xyz', 'abc'),
        isFalse,
      );
    });
  });
}
