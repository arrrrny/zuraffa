// Spec 034 — Track 4.3: XRayMockType enum + color mapping.
//
// Behaviors B01, B02: color palette + fromString.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/xray/xray_mock_type.dart';

void main() {
  group('XRayMockType', () {
    test('B01 — valid.color is neon green 0xFF00C853', () {
      expect(XRayMockType.valid.color, 0xFF00C853);
    });

    test('B01 — error.color is red 0xFFD50000', () {
      expect(XRayMockType.error.color, 0xFFD50000);
    });

    test('B01 — unknown.color is neutral grey 0xFF9E9E9E', () {
      expect(XRayMockType.unknown.color, 0xFF9E9E9E);
    });

    test('B01 — all colors are opaque (alpha 0xFF)', () {
      for (final t in XRayMockType.values) {
        final alpha = (t.color >> 24) & 0xFF;
        expect(alpha, 0xFF, reason: '${t.name} color must be opaque');
      }
    });

    test('B02 — fromString returns the right enum for known types', () {
      expect(XRayMockType.fromString('valid'), XRayMockType.valid);
      expect(XRayMockType.fromString('error'), XRayMockType.error);
      expect(XRayMockType.fromString('unknown'), XRayMockType.unknown);
    });

    test('B02 — fromString is case-insensitive', () {
      expect(XRayMockType.fromString('VALID'), XRayMockType.valid);
      expect(XRayMockType.fromString('Error'), XRayMockType.error);
      expect(XRayMockType.fromString('UnKnOwN'), XRayMockType.unknown);
    });

    test('B02 — fromString(null) returns unknown', () {
      expect(XRayMockType.fromString(null), XRayMockType.unknown);
    });

    test('B02 — fromString on garbage returns unknown', () {
      expect(XRayMockType.fromString('garbage'), XRayMockType.unknown);
      expect(XRayMockType.fromString(''), XRayMockType.unknown);
      expect(XRayMockType.fromString('banana'), XRayMockType.unknown);
    });

    test('label returns the canonical lower-case name', () {
      expect(XRayMockType.valid.label, 'valid');
      expect(XRayMockType.error.label, 'error');
      expect(XRayMockType.unknown.label, 'unknown');
    });
  });
}
