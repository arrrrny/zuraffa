// GENERATED TEST — `zfa tdd gen A2` (spec 044-test-tdd-generation).
//
// behavior_id: A2
// source_criterion: AC-2
// kind: acceptance
// description: the error is reported to the caller
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:example/tdd/004-login-ui/a2_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:example/tdd/004-login-ui/a2_subject.dart' as subject;

void main() {
  group('A2 (AC-2)', () {
    test('A2 — the error is reported to the caller', () {
      final Object? result = (() {
        try {
          subject.subject_a2();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
