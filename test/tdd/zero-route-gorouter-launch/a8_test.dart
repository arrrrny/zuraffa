// HAND-STEPPED TEST — real outcome assertion added at the A8:hand designed
// hand step (issue #1411 attestation below; vacuous-guard marker removed).
//
// behavior_id: A8
// source_criterion: AC-8
// description: they assert the new `errorBuilder` / fallback output and pass.
// zfa:tdd: A8:hand — hand step completed before first red certification (issue #1411)
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/zero-route-gorouter-launch/a8_subject.dart'
    as subject;

void main() {
  group('A8 (AC-8)', () {
    test(
      'A8 — they assert the new `errorBuilder` / fallback output and pass.',
      () {
        final result = (() {
          try {
            return subject.subject_a8();
          } on UnimplementedError catch (error) {
            return error;
          }
        })();
        expect(result, isNot(isA<UnimplementedError>()));
        // Hand-step assertion (issue #1488 remedy): pins the new emission
        // surface the updated app-shell/setup golden tests assert — the
        // errorBuilder, the empty-table fallback, the placeholder widget
        // and its user-facing hint, plus the app title threading
        // (issue #1673).
        expect(result, isA<String>());
        final emitted = result as String;
        expect(emitted, contains('errorBuilder: (context, state)'));
        expect(emitted, contains('getAllRoutes().isEmpty'));
        expect(emitted, contains('ZfaDayZeroPlaceholder'));
        expect(emitted, contains('No routes yet'));
        expect(emitted, contains('zfa route <Entity>'));
        expect(emitted, contains("'Todo App'"));
      },
    );
  });
}
