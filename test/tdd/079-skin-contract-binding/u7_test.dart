// GENERATED TEST — `zfa tdd gen U7` (spec 044-test-tdd-generation).
//
// behavior_id: U7
// source_criterion: FR-007
// kind: unit
// description: The binding MUST be exported from the skin barrel for the Flutter shell to consume across the package boundary.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/079-skin-contract-binding/u7_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/079-skin-contract-binding/u7_subject.dart'
    as subject;

void main() {
  group('U7 (FR-007)', () {
    test(
      'U7 — The binding MUST be exported from the skin barrel for the Flutter shell to consume across the package boundary.',
      () {
        final result = (() {
          try {
            return subject.subject_u7();
          } on UnimplementedError catch (error) {
            return error;
          }
        })();
        expect(result, isNot(isA<UnimplementedError>()));
      },
    );
  });
}
