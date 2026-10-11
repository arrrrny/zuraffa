// GENERATED TEST — `zfa tdd gen A2` (spec 044-test-tdd-generation).
//
// behavior_id: A2
// source_criterion: AC-2
// kind: acceptance
// description: the verdict is invalid with a reason naming the email field.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/004-login-ui/a2_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/004-login-ui/a2_subject.dart' as subject;

void main() {
  group('A2 (AC-2)', () {
    test(
      'A2 — the verdict is invalid with a reason naming the email field.',
      () {
        final verdict = subject.subject_a2();
        expect(
          verdict.ok,
          isFalse,
          reason: 'an email without @ is not well-formed (FR-001)',
        );
        expect(
          verdict.reasons,
          contains('email'),
          reason: 'the reason names the email field (AC-2)',
        );
      },
    );
  });
}
