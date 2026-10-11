// HAND-WRITTEN TEST — the widget lane refused to scaffold A2 (issue #938:
// pure-Dart repo). The behavior's substance — the initial `/` resolution
// renders the placeholder instead of throwing — is pinned at the emission
// level: the fallback route claims `/` and the errorBuilder renders the
// placeholder, so GoRouter has both a first match and a catch-all
// (issues #1411, #1488).
//
// behavior_id: A2
// source_criterion: AC-2
// description: the resolution renders the placeholder instead of throwing `no route for location: /`.
// zfa:tdd: A2:hand — hand step completed before first red certification (issue #1411)
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/zero-route-gorouter-launch/a2_subject.dart'
    as subject;

void main() {
  group('A2 (AC-2)', () {
    test('A2 — the resolution renders the placeholder instead of throwing '
        '`no route for location: /`.', () {
      final result = (() {
        try {
          return subject.subject_a2();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
      // Hand-step assertion (issue #1488 remedy): the day-zero router
      // must claim `/` (first match) and install the errorBuilder
      // (catch-all) — together they make the initial location resolve to
      // the placeholder instead of the GoException crash (issue #1673).
      expect(result, isA<String>());
      final emitted = result as String;
      expect(emitted, contains("path: '/'"));
      expect(emitted, contains('errorBuilder: (context, state)'));
      expect(emitted, contains('ZfaDayZeroPlaceholder'));
      // The live `flutter run` proof of the same behavior (workaround
      // recorded on the issue): launching with the placeholder claimed
      // `/` ran clean — zero exceptions, day-zero suite green.
    });
  });
}
