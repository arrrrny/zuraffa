// HAND-STEPPED TEST — real outcome assertion added at the A3:hand designed
// hand step (issue #1411 attestation below; vacuous-guard marker removed).
//
// behavior_id: A3
// source_criterion: AC-3
// description: it carries the same `errorBuilder` / empty-table fallback alongside the observer.
// zfa:tdd: A3:hand — hand step completed before first red certification (issue #1411)
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/zero-route-gorouter-launch/a3_subject.dart'
    as subject;

void main() {
  group('A3 (AC-3)', () {
    test(
      'A3 — it carries the same `errorBuilder` / empty-table fallback '
      'alongside the observer.',
      () {
        final Object? result = (() {
          try {
            return subject.subject_a3();
          } on UnimplementedError catch (error) {
            return error;
          }
        })();
        expect(result, isNot(isA<UnimplementedError>()));
        // Hand-step assertion (issue #1488 remedy): the skin-audit router
        // must carry the day-zero `errorBuilder` / empty-table fallback
        // (issue #1673) ALONGSIDE the #1102 SkinRouteContractObserver.
        expect(result, isA<String>());
        final emitted = result! as String;
        expect(emitted, contains('errorBuilder'));
        expect(emitted, contains('getAllRoutes().isEmpty'));
        expect(emitted, contains('ZfaDayZeroPlaceholder'));
        expect(emitted, contains('SkinRouteContractObserver'));
      },
    );
  });
}
