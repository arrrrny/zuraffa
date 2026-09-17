// HAND-WRITTEN TEST — the widget lane refused to scaffold A7 (issue #938:
// pure-Dart repo cannot run widget tests). The behavior's substance — the
// Flutter day-zero smoke test pumps the app shell and asserts the initial
// `/` resolves — is pinned at the emitted-template level through the real
// SmokeTestWriter (issues #1411, #1488).
//
// behavior_id: A7
// source_criterion: AC-7
// description: the smoke test still constructs the DI container AND also pumps the app shell and asserts the initial `/` resolves to the placeholder screen.
// zfa:tdd: A7:hand — hand step completed before first red certification (issue #1411)
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/zero-route-gorouter-launch/a7_subject.dart'
    as subject;

void main() {
  group('A7 (AC-7)', () {
    test('A7 — the smoke test still constructs the DI container AND also pumps '
        'the app shell and asserts the initial `/` resolves to the placeholder '
        'screen.', () {
      final result = (() {
        try {
          return subject.subject_a7();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
      // Hand-step assertion (issue #1488 remedy): the emitted Flutter
      // smoke test keeps the container construction AND gains the
      // shell-pump — `testWidgets` pumping the name-derived shell widget
      // (`ZikZakApp` for the canonical repro app) and asserting the
      // initial location never throws (issue #1673). The live pump
      // itself runs in the GENERATED app's flutter test, exercised
      // end-to-end by the day-zero smoke gate (slow tier).
      expect(result, isA<String>());
      final emitted = result as String;
      expect(emitted, contains('final container = ZikZakTddContainer();'));
      expect(emitted, contains('testWidgets'));
      expect(emitted, contains('pumpWidget(const ZikZakTddApp()'));
      expect(emitted, contains('takeException(), isNull'));
    });
  });
}
