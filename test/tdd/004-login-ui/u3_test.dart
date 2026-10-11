// GENERATED TEST — `zfa tdd gen U3` (spec 044-test-tdd-generation).
//
// behavior_id: U3
// source_criterion: FR-003, LoginValidation.validate
// kind: unit
// description: The system MUST keep the submit action disabled until the credential verdict is valid.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/004-login-ui/u3_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/004-login-ui/u3_subject.dart' as subject;

void main() {
  group('U3 (FR-003, LoginValidation.validate)', () {
    test(
      'U3 — The system MUST keep the submit action disabled until the credential verdict is valid.',
      () {
        // FR-003: the submit gate follows the verdict.
        expect(
          subject.subject_u3('user@example.com', 'longenough1').submitEnabled,
          isTrue,
          reason: 'valid credentials enable submit',
        );
        expect(
          subject.subject_u3('nope', 'short').submitEnabled,
          isFalse,
          reason: 'invalid credentials keep submit disabled',
        );
      },
    );
  });
}
