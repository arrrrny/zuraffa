// GENERATED TEST — `zfa tdd gen U1` (spec 044-test-tdd-generation).
//
// behavior_id: U1
// source_criterion: FR-001
// kind: unit
// description: The default priority returns 1 when a todo is created without an explicit priority.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../lib/tdd/u1_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:todo_tdd/tdd/u1_subject.dart' as subject;

void main() {
  group('U1 (FR-001)', () {
    test(
      'The default priority returns 1 when a todo is created without an explicit priority.',
      () {
        final Object result = (() {
          try {
            return subject.subject_u1();
          } on UnimplementedError catch (error) {
            return error;
          }
        })();
        expect(result, equals(1));
      },
    );
  });
}
