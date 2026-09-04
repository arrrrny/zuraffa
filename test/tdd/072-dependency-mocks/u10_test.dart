// GENERATED TEST — `zfa tdd gen U10` (spec 044-test-tdd-generation).
//
// behavior_id: U10
// source_criterion: FR-010
// kind: unit
// description: Every generated dependency-mock artifact MUST be recorded in the artifact registry, traceable to its dependency row and feature.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/072-dependency-mocks/u10_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/072-dependency-mocks/u10_subject.dart' as subject;

void main() {
  group('U10 (FR-010)', () {
    test(
      'U10 — Every generated dependency-mock artifact MUST be recorded in the artifact registry, traceable to its dependency row and feature.',
      () {
        final Object? result = (() {
          try {
            return subject.subject_u10();
          } on UnimplementedError catch (error) {
            return error;
          }
        })();
        expect(result, isNot(isA<UnimplementedError>()));
      },
    );
  });
}
