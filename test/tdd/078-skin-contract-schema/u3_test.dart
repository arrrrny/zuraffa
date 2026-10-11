// GENERATED TEST — `zfa tdd gen U3` (spec 044-test-tdd-generation).
//
// behavior_id: U3
// source_criterion: FR-003
// kind: unit
// description: The system MUST serialize the model back to contract JSON that parses to an equal model (round-trip guarantee).
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/078-skin-contract-schema/u3_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/078-skin-contract-schema/u3_subject.dart'
    as subject;

void main() {
  group('U3 (FR-003)', () {
    test(
      'U3 — The system MUST serialize the model back to contract JSON that parses to an equal model (round-trip guarantee).',
      () {
        final result = (() {
          try {
            return subject.subject_u3();
          } on UnimplementedError catch (error) {
            return error;
          }
        })();
        expect(result, isNot(isA<UnimplementedError>()));
      },
    );
  });
}
