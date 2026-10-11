// GENERATED TEST — `zfa tdd gen A4` (spec 044-test-tdd-generation).
//
// behavior_id: A4
// source_criterion: AC-4
// kind: acceptance
// description: the verdict is valid and the submit action is enabled.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/004-login-ui/a4_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/004-login-ui/a4_subject.dart' as subject;

void main() {
  group('A4 (AC-4)', () {
    test('A4 — the verdict is valid and the submit action is enabled.', () {
      final verdict = subject.subject_a4();
      expect(verdict.ok, isTrue, reason: 'valid credentials pass (AC-4)');
      expect(verdict.reasons, isEmpty);
      expect(
        verdict.submitEnabled,
        isTrue,
        reason:
            'the submit action is enabled when the verdict is valid (FR-003)',
      );
    });
  });
}
