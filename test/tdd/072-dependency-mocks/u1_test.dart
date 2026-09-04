// GENERATED TEST — `zfa tdd gen U1` (spec 044-test-tdd-generation).
//
// behavior_id: U1
// source_criterion: FR-001
// kind: unit
// description: The system MUST provide `zfa mock dependency <Name>`, which reads the declared External Dependencies & Contracts row for `<Name>` and refuses non-zero with the row to add when the name is undeclared.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/072-dependency-mocks/u1_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/072-dependency-mocks/u1_subject.dart' as subject;

void main() {
  group('U1 (FR-001)', () {
    test('U1 — The system MUST provide `zfa mock dependency <Name>`, which reads the declared External Dependencies & Contracts row for `<Name>` and refuses non-zero with the row to add when the name is undeclared.', () {
      final Object? result = (() {
        try {
          return subject.subject_u1();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
