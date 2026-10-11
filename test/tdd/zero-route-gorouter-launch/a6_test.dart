// HAND-STEPPED TEST — real outcome assertion added at the A6:hand designed
// hand step (issue #1411 attestation below; vacuous-guard marker removed).
//
// behavior_id: A6
// source_criterion: AC-6
// description: it stays router-free (no Flutter imports) — only the Flutter flavor gains router coverage.
// zfa:tdd: A6:hand — hand step completed before first red certification (issue #1411)
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/zero-route-gorouter-launch/a6_subject.dart'
    as subject;

void main() {
  group('A6 (AC-6)', () {
    test('A6 — it stays router-free (no Flutter imports) — only the Flutter '
        'flavor gains router coverage.', () {
      final result = (() {
        try {
          return subject.subject_a6();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
      // Hand-step assertion (issue #1488 remedy): the pure-Dart smoke
      // test flavor has no app module, no router and no Flutter imports
      // (issue #664) — the #1673 router coverage must not leak into it.
      expect(result, isA<String>());
      final emitted = result as String;
      expect(emitted, isNot(contains('GoRouter')));
      expect(emitted, isNot(contains('testWidgets')));
      expect(emitted, isNot(contains('pumpWidget')));
      expect(emitted, isNot(contains('package:flutter')));
      expect(emitted, contains('package:test/test.dart'));
      expect(emitted, contains('bootstrap smoke'));
    });
  });
}
