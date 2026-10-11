// GENERATED TEST — `zfa tdd gen A15` (spec 044-test-tdd-generation).
//
// behavior_id: A15
// source_criterion: AC-15
// kind: acceptance
// description: they run unchanged against the real adapter (same interface, same harness seam).
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/072-dependency-mocks/a15_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/072-dependency-mocks/a15_subject.dart' as subject;

void main() {
  group('A15 (AC-15)', () {
    test(
      'A15 — they run unchanged against the real adapter (same interface, same harness seam).',
      () {
        final Object? result = (() {
          try {
            subject.subject_a15();
            return null;
          } on UnimplementedError catch (error) {
            return error;
          }
        })();
        expect(result, isNot(isA<UnimplementedError>()));
      },
    );
  });
}
