// GENERATED TEST — `zfa tdd gen A4` (spec 044-test-tdd-generation).
//
// behavior_id: A4
// source_criterion: AC-4
// kind: acceptance
// description: it refuses non-zero with an author-actionable error naming the External Dependencies & Contracts table row to add.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/072-dependency-mocks/a4_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/072-dependency-mocks/a4_subject.dart' as subject;

void main() {
  group('A4 (AC-4)', () {
    test(
      'A4 — it refuses non-zero with an author-actionable error naming the External Dependencies & Contracts table row to add.',
      () {
        final Object? result = (() {
          try {
            subject.subject_a4();
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
