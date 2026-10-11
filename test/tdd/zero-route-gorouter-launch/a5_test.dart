// HAND-STEPPED TEST — real outcome assertion added at the A5:hand designed
// hand step (issue #1411 attestation below; vacuous-guard marker removed).
//
// behavior_id: A5
// source_criterion: AC-5
// description: the placeholder behavior is unaffected because the fallback is runtime-side in the generated router.
// zfa:tdd: A5:hand — hand step completed before first red certification (issue #1411)
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/zero-route-gorouter-launch/a5_subject.dart'
    as subject;

void main() {
  group('A5 (AC-5)', () {
    test('A5 — the placeholder behavior is unaffected because the fallback is '
        'runtime-side in the generated router.', () {
      final result = (() {
        try {
          return subject.subject_a5();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
      // Hand-step assertion (issue #1488 remedy): the fallback must live
      // RUNTIME-SIDE in the emitted `app_router.dart` — never inside
      // `routing/index.dart`, which `zfa route`'s index regenerator
      // rewrites (or deletes when no modules exist). The regenerator's
      // source must therefore never reference the placeholder.
      expect(result, isA<Map<String, String>>());
      final observations = result as Map<String, String>;
      final router = observations['router']!;
      expect(router, contains('getAllRoutes().isEmpty'));
      expect(router, contains('ZfaDayZeroPlaceholder'));
      expect(router, contains("import 'index.dart';"));
      final routeBuilderSource = observations['routeBuilderSource']!;
      expect(
        routeBuilderSource,
        isNot(contains('ZfaDayZeroPlaceholder')),
        reason:
            'the index regenerator must not emit or reference the '
            'day-zero placeholder — it rewrites routing/index.dart and '
            'would clobber an index-side placeholder (issue #1673)',
      );
    });
  });
}
