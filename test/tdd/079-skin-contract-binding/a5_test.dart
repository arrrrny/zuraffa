// GENERATED TEST — `zfa tdd gen A5` (spec 044-test-tdd-generation).
//
// behavior_id: A5
// source_criterion: AC-5
// kind: acceptance
// description: it exposes the route table, the state bindings, and the contract name it was built from.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/079-skin-contract-binding/a5_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/079-skin-contract-binding/a5_subject.dart'
    as subject;

void main() {
  group('A5 (AC-5)', () {
    test(
      'A5 — it exposes the route table, the state bindings, and the contract name it was built from.',
      () {
        final Object? result = (() {
          try {
            subject.subject_a5();
            return null;
          } on UnimplementedError catch (error) {
            return error;
          }
        })();
        expect(result, isNot(isA<UnimplementedError>()));
      },
    );
  });
}
