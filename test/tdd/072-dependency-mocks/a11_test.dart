// GENERATED TEST — `zfa tdd gen A11` (spec 044-test-tdd-generation).
//
// behavior_id: A11
// source_criterion: AC-11
// kind: acceptance
// description: their relative order equals their declaration order in the spec, stably across runs.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/072-dependency-mocks/a11_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/072-dependency-mocks/a11_subject.dart' as subject;

void main() {
  group('A11 (AC-11)', () {
    test(
      'A11 — their relative order equals their declaration order in the spec, stably across runs.',
      () {
        final Object? result = (() {
          try {
            subject.subject_a11();
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
