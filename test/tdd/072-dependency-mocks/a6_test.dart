// GENERATED TEST — `zfa tdd gen A6` (spec 044-test-tdd-generation).
//
// behavior_id: A6
// source_criterion: AC-6
// kind: acceptance
// description: the harness wires the generated `FirebaseAuth` mock and the behavior tests through it.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/072-dependency-mocks/a6_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/072-dependency-mocks/a6_subject.dart' as subject;

void main() {
  group('A6 (AC-6)', () {
    test(
      'A6 — the harness wires the generated `FirebaseAuth` mock and the behavior tests through it.',
      () {
        final Object? result = (() {
          try {
            subject.subject_a6();
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
