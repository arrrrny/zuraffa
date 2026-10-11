// GENERATED TEST — `zfa tdd gen U2` (spec 044-test-tdd-generation).
//
// behavior_id: U2
// source_criterion: FR-002
// kind: unit
// description: The system MUST parse contract JSON into the model, failing with an error that names the offending section or key when input is malformed, incomplete, or carries unknown fields.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/078-skin-contract-schema/u2_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/078-skin-contract-schema/u2_subject.dart'
    as subject;

void main() {
  group('U2 (FR-002)', () {
    test(
      'U2 — The system MUST parse contract JSON into the model, failing with an error that names the offending section or key when input is malformed, incomplete, or carries unknown fields.',
      () {
        final result = (() {
          try {
            return subject.subject_u2();
          } on UnimplementedError catch (error) {
            return error;
          }
        })();
        expect(result, isNot(isA<UnimplementedError>()));
      },
    );
  });
}
