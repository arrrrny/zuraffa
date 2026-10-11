// GENERATED TEST — `zfa tdd gen A5` (spec 044-test-tdd-generation).
//
// behavior_id: A5
// source_criterion: AC-5
// kind: acceptance
// description: the result is a success carrying the authenticated user's email.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/004-login-ui/a5_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/004-login-ui/a5_subject.dart' as subject;

void main() {
  group('A5 (AC-5)', () {
    test(
      'A5 — the result is a success carrying the authenticated user\'s email.',
      () {
        final result = subject.subject_a5();
        expect(
          result.isSuccess,
          isTrue,
          reason: 'an accepting gateway yields success (AC-5)',
        );
        expect(
          result.email,
          'user@example.com',
          reason: 'the success carries the authenticated user email (FR-004)',
        );
        expect(result.error, isNull, reason: 'success carries a null error');
      },
    );
  });
}
