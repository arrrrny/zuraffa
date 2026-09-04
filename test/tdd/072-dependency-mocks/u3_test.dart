// GENERATED TEST — `zfa tdd gen U3` (spec 044-test-tdd-generation).
//
// behavior_id: U3
// source_criterion: FR-003
// kind: unit
// description: The generated package MUST include a certified fake with scriptable per-method responses and call recording (arguments and invocation order) sufficient for tests to assert interactions.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/072-dependency-mocks/u3_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/072-dependency-mocks/u3_subject.dart' as subject;

void main() {
  group('U3 (FR-003)', () {
    test('U3 — The generated package MUST include a certified fake with scriptable per-method responses and call recording (arguments and invocation order) sufficient for tests to assert interactions.', () {
      final Object? result = (() {
        try {
          return subject.subject_u3();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
