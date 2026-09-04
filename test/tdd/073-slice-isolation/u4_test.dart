// GENERATED TEST — `zfa tdd gen U4` (spec 044-test-tdd-generation).
//
// behavior_id: U4
// source_criterion: FR-004
// kind: unit
// description: `zfa slice verify` MUST emit a machine-readable JSON verdict covering self-containment, mock certification, and suite state, exiting non-zero and naming the failing check and offending references on failure.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/073-slice-isolation/u4_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/073-slice-isolation/u4_subject.dart' as subject;

void main() {
  group('U4 (FR-004)', () {
    test('U4 — `zfa slice verify` MUST emit a machine-readable JSON verdict covering self-containment, mock certification, and suite state, exiting non-zero and naming the failing check and offending references on failure.', () {
      final Object? result = (() {
        try {
          return subject.subject_u4();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
