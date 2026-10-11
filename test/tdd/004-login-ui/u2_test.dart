// GENERATED TEST — `zfa tdd gen U2` (spec 044-test-tdd-generation).
//
// behavior_id: U2
// source_criterion: FR-002, LoginValidation.validate
// kind: unit
// description: The system MUST require the password to be at least 8 characters long.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/004-login-ui/u2_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/004-login-ui/u2_subject.dart' as subject;

void main() {
  group('U2 (FR-002, LoginValidation.validate)', () {
    test(
      'U2 — The system MUST require the password to be at least 8 characters long.',
      () {
        // FR-002: the password floor is 8 characters.
        expect(
          subject.subject_u2('user@example.com', '12345678').ok,
          isTrue,
          reason: 'exactly 8 characters satisfies the policy',
        );
        expect(
          subject.subject_u2('user@example.com', '1234567').reasons,
          contains('password'),
          reason: '7 characters is rejected',
        );
      },
    );
  });
}
