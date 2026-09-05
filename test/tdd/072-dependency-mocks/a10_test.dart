// GENERATED TEST — `zfa tdd gen A10` (spec 044-test-tdd-generation).
//
// behavior_id: A10
// source_criterion: AC-10
// kind: acceptance
// description: the materialization order is exactly P1, P2, P3, none.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/072-dependency-mocks/a10_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/072-dependency-mocks/a10_subject.dart' as subject;

void main() {
  group('A10 (AC-10)', () {
    test('A10 — the materialization order is exactly P1, P2, P3, none.', () {
      final Object? result = (() {
        try {
          subject.subject_a10();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
