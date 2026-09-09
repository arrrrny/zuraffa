// GENERATED TEST — `zfa tdd gen U6` (spec 044-test-tdd-generation).
//
// behavior_id: U6
// source_criterion: FR-006, LoginValidation.validate
// kind: unit
// description: Validation MUST be deterministic: the same input always yields the same verdict.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/004-login-ui/u6_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/004-login-ui/u6_subject.dart' as subject;

void main() {
  group('U6 (FR-006, LoginValidation.validate)', () {
    test(
      'U6 — Validation MUST be deterministic: the same input always yields the same verdict.',
      () {
        // FR-006: determinism — the same input always yields the same verdict.
        final first = subject.subject_u6('user@example.com', 'longenough1');
        final second = subject.subject_u6('user@example.com', 'longenough1');
        expect(first.ok, second.ok);
        expect(first.reasons, second.reasons);
        final a = subject.subject_u6('bad', 'x');
        final b = subject.subject_u6('bad', 'x');
        expect(a.reasons, b.reasons);
        expect(a.ok, b.ok);
      },
    );
  });
}
