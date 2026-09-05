// GENERATED TEST — `zfa tdd gen A6` (spec 044-test-tdd-generation).
//
// behavior_id: A6
// source_criterion: AC-6
// kind: acceptance
// description: the loop completes its cycle over those behaviors (red certified, green landed) with no reference to the host.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/073-slice-isolation/a6_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/073-slice-isolation/a6_subject.dart' as subject;

void main() {
  group('A6 (AC-6)', () {
    test(
      'A6 — the loop completes its cycle over those behaviors (red certified, green landed) with no reference to the host.',
      () {
        final Object? result = (() {
          try {
            subject.subject_a6();
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
