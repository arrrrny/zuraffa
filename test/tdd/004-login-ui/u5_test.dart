// GENERATED TEST — `zfa tdd gen U5` (spec 044-test-tdd-generation).
//
// behavior_id: U5
// source_criterion: FR-005, AuthGateway.signIn
// kind: unit
// description: The system MUST map a rejected auth attempt to a result carrying a non-empty error reason and a null user email.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/004-login-ui/u5_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/004-login-ui/u5_subject.dart' as subject;

void main() {
  group('U5 (FR-005, AuthGateway.signIn)', () {
    test(
      'U5 — The system MUST map a rejected auth attempt to a result carrying a non-empty error reason and a null user email.',
      () {
        final result = subject.subject_u5();
        expect(
          result.error,
          isNotNull,
          reason: 'a rejected attempt maps a non-empty reason (FR-005)',
        );
        expect(
          result.email,
          isNull,
          reason: 'a rejected attempt maps a null email',
        );
      },
    );
  });
}
