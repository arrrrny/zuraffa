// HAND-STEPPED TEST — real outcome assertion added at the A4:hand designed
// hand step (issue #1411 attestation below; vacuous-guard marker removed).
//
// behavior_id: A4
// source_criterion: AC-4
// description: the runtime empty-check leaves the real route table untouched (fallback only fires on an empty table).
// zfa:tdd: A4:hand — hand step completed before first red certification (issue #1411)
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/zero-route-gorouter-launch/a4_subject.dart'
    as subject;

void main() {
  group('A4 (AC-4)', () {
    test('A4 — the runtime empty-check leaves the real route table untouched '
        '(fallback only fires on an empty table).', () {
      final result = (() {
        try {
          return subject.subject_a4();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
      // Hand-step assertion (issue #1488 remedy): the emitted router's
      // `routes:` argument is a runtime ternary — the real table is used
      // as-is when non-empty, and only an EMPTY table swaps in the
      // placeholder `/` route (issue #1673).
      expect(result, isA<String>());
      final emitted = result as String;
      expect(emitted, contains('getAllRoutes().isEmpty'));
      expect(emitted, contains(': getAllRoutes()'));
      expect(emitted, contains("path: '/'"));
      expect(emitted, contains('ZfaDayZeroPlaceholder'));
    });
  });
}
