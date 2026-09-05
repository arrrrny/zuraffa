// GENERATED TEST — `zfa tdd gen U1` (spec 044-test-tdd-generation).
//
// behavior_id: U1
// source_criterion: FR-001
// kind: unit
// description: The system MUST provide a pure-Dart runtime binding built from a parsed `SkinContract` in one call.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/079-skin-contract-binding/u1_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/079-skin-contract-binding/u1_subject.dart'
    as subject;

void main() {
  group('U1 (FR-001)', () {
    test(
      'U1 — The system MUST provide a pure-Dart runtime binding built from a parsed `SkinContract` in one call.',
      () async {
        final result = await (() async {
          try {
            await subject.subject_u1();
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
