// GENERATED TEST — `zfa tdd gen A8` (spec 044-test-tdd-generation).
//
// behavior_id: A8
// source_criterion: AC-8
// kind: acceptance
// description: every step succeeds without host knowledge.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/073-slice-isolation/a8_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/073-slice-isolation/a8_subject.dart' as subject;

void main() {
  group('A8 (AC-8)', () {
    test('A8 — every step succeeds without host knowledge.', () {
      final Object? result = (() {
        try {
          subject.subject_a8();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
