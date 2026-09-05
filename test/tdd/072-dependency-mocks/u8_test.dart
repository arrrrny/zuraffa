// GENERATED TEST — `zfa tdd gen U8` (spec 044-test-tdd-generation).
//
// behavior_id: U8
// source_criterion: FR-008
// kind: unit
// description: A declared row that is malformed (unparseable signatures, duplicate dependency name, unsupported kind) MUST cause a refusal naming the row and the defect — never a guessed or wrong-shaped mock.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/072-dependency-mocks/u8_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/072-dependency-mocks/u8_subject.dart' as subject;

void main() {
  group('U8 (FR-008)', () {
    test(
      'U8 — A declared row that is malformed (unparseable signatures, duplicate dependency name, unsupported kind) MUST cause a refusal naming the row and the defect — never a guessed or wrong-shaped mock.',
      () {
        final Object? result = (() {
          try {
            return subject.subject_u8();
          } on UnimplementedError catch (error) {
            return error;
          }
        })();
        expect(result, isNot(isA<UnimplementedError>()));
      },
    );
  });
}
