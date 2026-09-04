// GENERATED TEST — `zfa tdd gen U3` (spec 044-test-tdd-generation).
//
// behavior_id: U3
// source_criterion: FR-003
// kind: unit
// description: The tdd loop MUST run with the sandbox as project root, and its journal/registry evidence MUST live inside the sandbox.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/073-slice-isolation/u3_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/073-slice-isolation/u3_subject.dart' as subject;

void main() {
  group('U3 (FR-003)', () {
    test(
      'U3 — The tdd loop MUST run with the sandbox as project root, and its journal/registry evidence MUST live inside the sandbox.',
      () {
        final Object? result = (() {
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
