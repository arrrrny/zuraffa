// GENERATED TEST — `zfa tdd gen U1` (spec 044-test-tdd-generation).
//
// behavior_id: U1
// source_criterion: FR-001, LoginValidation.validate
// kind: unit
// description: The system MUST treat an email as well-formed only when it contains a non-empty local part, an `@` separator, and a non-empty domain containing a `.`.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/004-login-ui/u1_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/004-login-ui/u1_subject.dart' as subject;

void main() {
  group('U1 (FR-001, LoginValidation.validate)', () {
    test(
      'U1 — The system MUST treat an email as well-formed only when it contains a non-empty local part, an `@` separator, and a non-empty domain containing a `.`.',
      () {
        // FR-001: well-formed == non-empty local part, one @, non-empty
        // domain containing a dot.
        expect(
          subject.subject_u1('user@example.com', 'longenough1').ok,
          isTrue,
          reason: 'a well-formed email passes',
        );
        expect(
          subject.subject_u1('@example.com', 'longenough1').reasons,
          contains('email'),
          reason: 'empty local part is rejected',
        );
        expect(
          subject.subject_u1('userexample.com', 'longenough1').reasons,
          contains('email'),
          reason: 'missing @ separator is rejected',
        );
        expect(
          subject.subject_u1('user@examplecom', 'longenough1').reasons,
          contains('email'),
          reason: 'domain without a dot is rejected',
        );
        expect(
          subject.subject_u1('user@example..com', 'longenough1').reasons,
          contains('email'),
          reason: 'empty domain label is rejected',
        );
      },
    );
  });
}
