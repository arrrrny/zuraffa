// GENERATED TEST — `zfa tdd gen A3` (spec 044-test-tdd-generation).
//
// behavior_id: A3
// source_criterion: AC-3
// kind: acceptance
// description: the verdict is invalid with a reason naming the password field.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/004-login-ui/a3_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/004-login-ui/a3_subject.dart' as subject;

void main() {
  group('A3 (AC-3)', () {
    test(
      'A3 — the verdict is invalid with a reason naming the password field.',
      () {
        final verdict = subject.subject_a3();
        expect(
          verdict.ok,
          isFalse,
          reason:
              'a 7-character password is under the 8-character floor (FR-002)',
        );
        expect(
          verdict.reasons,
          contains('password'),
          reason: 'the reason names the password field (AC-3)',
        );
        expect(
          verdict.reasons,
          isNot(contains('email')),
          reason: 'the email itself is well-formed here',
        );
      },
    );
  });
}
