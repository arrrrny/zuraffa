// GENERATED TEST — `zfa tdd gen U2` (spec 044-test-tdd-generation).
//
// behavior_id: U2
// source_criterion: FR-002
// kind: unit
// description: The maximum title length returns 120 when a title is validated.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../lib/tdd/u2_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:todo_tdd/tdd/u2_subject.dart' as subject;

void main() {
  group('U2 (FR-002)', () {
    test('The maximum title length returns 120 when a title is validated.', () {
      final Object result = (() {
        try {
          return subject.subject_u2();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, equals(120));
    });
  });
}
