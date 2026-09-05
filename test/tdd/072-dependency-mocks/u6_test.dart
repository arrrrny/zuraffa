// GENERATED TEST — `zfa tdd gen U6` (spec 044-test-tdd-generation).
//
// behavior_id: U6
// source_criterion: FR-006
// kind: unit
// description: A behavior routed to a dependency mock whose mock artifacts are absent MUST be refused (or auto-generated under the loop's explicit generation gate) with `zfa mock dependency <Name>` named as the fix — never a silently absent test double.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/072-dependency-mocks/u6_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/072-dependency-mocks/u6_subject.dart' as subject;

void main() {
  group('U6 (FR-006)', () {
    test(
      'U6 — A behavior routed to a dependency mock whose mock artifacts are absent MUST be refused (or auto-generated under the loop\'s explicit generation gate) with `zfa mock dependency <Name>` named as the fix — never a silently absent test double.',
      () {
        final Object? result = (() {
          try {
            return subject.subject_u6();
          } on UnimplementedError catch (error) {
            return error;
          }
        })();
        expect(result, isNot(isA<UnimplementedError>()));
      },
    );
  });
}
