// GENERATED TEST — `zfa tdd gen A13` (spec 044-test-tdd-generation).
//
// behavior_id: A13
// source_criterion: AC-13
// kind: acceptance
// description: it is green.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/073-slice-isolation/a13_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/073-slice-isolation/a13_subject.dart' as subject;

void main() {
  group('A13 (AC-13)', () {
    test('A13 — it is green.', () {
      final Object? result = (() {
        try {
          subject.subject_a13();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
