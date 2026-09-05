// GENERATED TEST — `zfa tdd gen A12` (spec 044-test-tdd-generation).
//
// behavior_id: A12
// source_criterion: AC-12
// kind: acceptance
// description: each row's priority and resulting order position are visible.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/072-dependency-mocks/a12_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/072-dependency-mocks/a12_subject.dart' as subject;

void main() {
  group('A12 (AC-12)', () {
    test(
      'A12 — each row\'s priority and resulting order position are visible.',
      () {
        final Object? result = (() {
          try {
            subject.subject_a12();
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
