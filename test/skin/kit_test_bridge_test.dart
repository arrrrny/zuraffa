// Issue #1112 — the widget-test bridge: `zfaAnchorTapped(tester,
// zfaKey)` performs the same anchor-by-key lookup in widget tests and
// settles the tree afterwards (safe: the test-tree anchor cannot
// reschedule itself — subscribe-don't-poll, pilot lesson 5).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/builders/skin_contract_kit_builder.dart';

void main() {
  group('issue #1112 — zfaAnchorTapped (emitted widget-test bridge)', () {
    test('T6.1 the kit emits the bridge file (deterministic, skip-if-exists)',
        () {
      final bridge = const SkinAnchorTestBridgeBuilder().build();
      expect(bridge, contains('Future<TapResult> zfaAnchorTapped('));
      expect(bridge, contains('GENERATED - DO NOT EDIT'));
      // Deterministic: same bytes on the second emission.
      expect(
        const SkinAnchorTestBridgeBuilder().build(),
        bridge,
      );
    });

    test('T6.2 the bridge signature matches the issue', () {
      final bridge = const SkinAnchorTestBridgeBuilder().build();
      expect(
        bridge,
        contains(
          'Future<TapResult> zfaAnchorTapped(WidgetTester tester, '
          'String zfaKey)',
        ),
      );
    });

    test('T6.3 same lookup + pumpAndSettle after the tap', () {
      final bridge = const SkinAnchorTestBridgeBuilder().build();
      // The SAME anchor-by-key lookup the driver seam uses.
      final tapIndex = bridge.indexOf('debugTapAnchorSync(zfaKey)');
      // The executable settle AFTER the tap (not the doc mention).
      final settleIndex = bridge.indexOf('await tester.pumpAndSettle()');
      expect(tapIndex, greaterThanOrEqualTo(0));
      expect(settleIndex, greaterThan(tapIndex));
    });

    test('T6.4 the bridge returns TapResult (same JSON shape as drive)', () {
      final bridge = const SkinAnchorTestBridgeBuilder().build();
      expect(bridge, contains('Future<TapResult>'));
      expect(bridge, contains("import 'package:flutter_test/flutter_test.dart'"));
    });
  });
}
