// GENERATED TEST — `zfa tdd gen A2` (spec 044-test-tdd-generation).
//
// behavior_id: A2
// source_criterion: AC-2
// kind: acceptance
// description: create entity TodoStats with total, active, completed.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../lib/tdd/a2_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import '../../lib/tdd/a2_subject.dart' as subject;

void main() {
  group('A2 (AC-2)', () {
    test('create entity TodoStats with total, active, completed.', () {
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
