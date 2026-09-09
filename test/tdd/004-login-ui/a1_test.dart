// GENERATED TEST — `zfa tdd gen A1` (spec 044-test-tdd-generation).
//
// behavior_id: A1
// source_criterion: AC-1
// kind: acceptance
// description: the verdict is invalid with a reason naming the email field first.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/004-login-ui/a1_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/004-login-ui/a1_subject.dart' as subject;

void main() {
  group('A1 (AC-1)', () {
    test(
      'A1 — the verdict is invalid with a reason naming the email field first.',
      () {
        final verdict = subject.subject_a1();
        expect(verdict.ok, isFalse, reason: 'empty credentials are invalid');
        expect(
          verdict.reasons.first,
          'email',
          reason: 'the FIRST reason names the email field (AC-1)',
        );
      },
    );
  });
}
