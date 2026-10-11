// GENERATED TEST — `zfa tdd gen U4` (spec 044-test-tdd-generation).
//
// behavior_id: U4
// source_criterion: FR-004, AuthGateway.signIn
// kind: unit
// description: The system MUST map a successful auth attempt to a result carrying the user's email and a null error.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/004-login-ui/u4_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/004-login-ui/u4_subject.dart' as subject;

void main() {
  group('U4 (FR-004, AuthGateway.signIn)', () {
    test(
      'U4 — The system MUST map a successful auth attempt to a result carrying the user\'s email and a null error.',
      () {
        final result = subject.subject_u4();
        expect(
          result.email,
          'user@example.com',
          reason: 'a successful attempt maps the user email (FR-004)',
        );
        expect(result.error, isNull, reason: 'success maps a null error');
      },
    );
  });
}
