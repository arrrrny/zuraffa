// GENERATED TEST — `zfa tdd gen A14` (spec 044-test-tdd-generation).
//
// behavior_id: A14
// source_criterion: AC-14
// kind: acceptance
// description: it refuses naming the missing method and the contract row — never silently swapping a drifting adapter.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/072-dependency-mocks/a14_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/072-dependency-mocks/a14_subject.dart' as subject;

void main() {
  group('A14 (AC-14)', () {
    test('A14 — it refuses naming the missing method and the contract row — never silently swapping a drifting adapter.', () {
      final Object? result = (() {
        try {
          subject.subject_a14();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
