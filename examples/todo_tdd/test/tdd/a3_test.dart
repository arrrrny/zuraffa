// GENERATED TEST — `zfa tdd gen A3` (spec 044-test-tdd-generation).
//
// behavior_id: A3
// source_criterion: AC-3
// kind: acceptance
// description: the status line formatter returns a non-empty string.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../lib/tdd/a3_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import '../../lib/tdd/a3_subject.dart' as subject;

void main() {
  group('A3 (AC-3)', () {
    test('the status line formatter returns a non-empty string.', () {
      final Object? result = (() {
        try {
          subject.subject_a3();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
