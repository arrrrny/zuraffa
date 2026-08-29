// Spec 034 — Track 4.3: XRayControlDeck release-mode strip regression.
// Issue #185 — SC-003: Release builds contain zero X-Ray-related code.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/core/xray_config.dart';
import 'package:zuraffa/src/plugins/xray/xray_control_deck.dart';
import 'package:zuraffa/src/plugins/xray/xray_mock_entry.dart';

void main() {
  group('SC-003 — X-Ray Control Deck release-mode strip (issue #185)', () {
    test('kXrayReleaseMode is a compile-time constant (false in tests)', () {
      expect(kXrayReleaseMode, isFalse);
    });

    test('B13 — release-mode deck.registerEntries is a no-op', () {
      final deck = XRayControlDeck(isReleaseMode: true);
      deck.registerEntries(const [
        XRayMockEntry(name: 'A', payload: 'p1'),
        XRayMockEntry(name: 'B', payload: 'p2'),
      ]);
      expect(deck.entries, isEmpty,
          reason: 'release builds MUST NOT register mock entries');
    });

    test('B14 — release-mode inject returns null', () {
      final deck = XRayControlDeck(isReleaseMode: true);
      expect(deck.inject('A'), isNull);
    });

    test('B15 — release-mode find returns null', () {
      final deck = XRayControlDeck(isReleaseMode: true);
      expect(deck.find('A', 'p1'), isNull);
    });

    test('B16 — release-mode toJson reports release_mode: true', () {
      final deck = XRayControlDeck(isReleaseMode: true);
      final j = deck.toJson();
      expect(j['release_mode'], isTrue);
      expect(j['active'], isFalse);
      expect(j['entries'], isEmpty);
    });

    test('release-mode clear is a no-op (does not throw, does not emit)', () {
      final deck = XRayControlDeck(isReleaseMode: true);
      // No throw.
      deck.clear();
      expect(deck.entries, isEmpty);
    });
  });
}
