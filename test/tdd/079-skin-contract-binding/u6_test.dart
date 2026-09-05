// GENERATED TEST — `zfa tdd gen U6` (spec 044-test-tdd-generation).
//
// behavior_id: U6
// source_criterion: FR-006
// kind: unit
// description: The binding MUST stay free of any UI-framework dependency (engine lane, pure Dart).
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/079-skin-contract-binding/u6_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/079-skin-contract-binding/u6_subject.dart'
    as subject;

void main() {
  group('U6 (FR-006)', () {
    test(
      'U6 — The binding MUST stay free of any UI-framework dependency (engine lane, pure Dart).',
      () async {
        final result = await (() async {
          try {
            await subject.subject_u6();
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
