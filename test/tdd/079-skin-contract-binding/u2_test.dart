// GENERATED TEST — `zfa tdd gen U2` (spec 044-test-tdd-generation).
//
// behavior_id: U2
// source_criterion: FR-002
// kind: unit
// description: The binding MUST derive the runtime route table from `contract.routes`, preserving the navigator-root conforming-by-construction rule.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/079-skin-contract-binding/u2_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/079-skin-contract-binding/u2_subject.dart'
    as subject;

void main() {
  group('U2 (FR-002)', () {
    test(
      'U2 — The binding MUST derive the runtime route table from `contract.routes`, preserving the navigator-root conforming-by-construction rule.',
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
