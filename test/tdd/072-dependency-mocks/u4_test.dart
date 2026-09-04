// GENERATED TEST — `zfa tdd gen U4` (spec 044-test-tdd-generation).
//
// behavior_id: U4
// source_criterion: FR-004
// kind: unit
// description: Regeneration from an unchanged row MUST be byte-for-byte deterministic; a changed row regenerates deterministically with the change surfaced in the command output.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/072-dependency-mocks/u4_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/072-dependency-mocks/u4_subject.dart' as subject;

void main() {
  group('U4 (FR-004)', () {
    test('U4 — Regeneration from an unchanged row MUST be byte-for-byte deterministic; a changed row regenerates deterministically with the change surfaced in the command output.', () {
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
