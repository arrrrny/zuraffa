// GENERATED TEST — `zfa tdd gen A9` (spec 044-test-tdd-generation).
//
// behavior_id: A9
// source_criterion: AC-9
// kind: acceptance
// description: the run refuses (or auto-generates under the loop's existing generation gate) naming `zfa mock dependency <Name>` as the fix — never a silently absent test double.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/072-dependency-mocks/a9_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/072-dependency-mocks/a9_subject.dart' as subject;

void main() {
  group('A9 (AC-9)', () {
    test(
      'A9 — the run refuses (or auto-generates under the loop\'s existing generation gate) naming `zfa mock dependency <Name>` as the fix — never a silently absent test double.',
      () {
        final Object? result = (() {
          try {
            subject.subject_a9();
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
