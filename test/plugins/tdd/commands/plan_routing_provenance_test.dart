// A1 (feature 071): declared lanes route end-to-end — a scenario's
// `**Type**` declaration decides its lane regardless of the verbs in
// its prose (the #950 func-verb hijack and the #936 past-tense
// misroute become unreachable for DECLARED scenarios), and rewording
// prose never changes routing (SC-001). During the fallback window an
// UNDECLARED scenario still routes by the legacy classifier (SC-005).
// Issue #951; spec FR-001/FR-013.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

Behavior? parseOne(String scenario) {
  final spec = '## Scenarios\n\n1. **Given** the app state, **When** it '
      'changes, **Then** $scenario\n';
  final behaviors = const SpecParser().parse('071-probe', spec);
  return behaviors.where((b) => b.id == 'A1').firstOrNull;
}

void main() {
  group('A1: declarations decide the lane, prose does not', () {
    test('a marker-declared UNIT scenario whose prose says "renders the '
        'widget" stays in the unit lane', () {
      final b = parseOne(
        'the total equals the sum.\n   **Type**: unit\n',
        // prose mentions the widget noun — the #830 sniffer would
        // claim it pre-declarations
      );
      expect(b?.kind, BehaviorKind.unit);
    });

    test('a marker-declared WIDGET scenario whose prose says "returns" '
        'never falls to the acceptance lane', () {
      final b = parseOne(
        'the widget returns the rendered title.\n   **Type**: widget\n',
      );
      expect(b?.kind, BehaviorKind.widget);
    });

    test('reworded prose with identical markers routes identically '
        '(SC-001)', () {
      Behavior? parse(String prose) => parseOne(
        '$prose\n   **Type**: widget\n',
      );
      final a = parse('the widget renders "Order placed".');
      final b = parse('the widget rendered the order confirmation.');
      final c = parse('the order screen computes its total.');
      expect(a?.kind, BehaviorKind.widget);
      expect(b?.kind, a?.kind, reason: 'past tense, same declaration');
      expect(c?.kind, a?.kind, reason: 'no UI verb at all, same declaration');
    });

    test('an UNDECLARED scenario keeps the legacy fallback routing '
        '(fallback window, SC-005)', () {
      final widgetProse = parseOne('the page shows the settings form.');
      final plainProse = parseOne('the total equals the sum of items.');
      expect(widgetProse?.kind, BehaviorKind.widget,
          reason: 'legacy classifier still routes undeclared scenarios');
      expect(plainProse?.kind, BehaviorKind.acceptance);
    });
  });
}
