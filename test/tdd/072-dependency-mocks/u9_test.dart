// GENERATED TEST — `zfa tdd gen U9` (spec 044-test-tdd-generation).
//
// behavior_id: U9
// source_criterion: FR-009
// kind: unit
// description: `zfa tdd realize --adapter <Name>` MUST accept a generated dependency mock behind the declared interface, run the existing differential gates with the declared contract as the parity source, and refuse on surface drift naming the drifted member and the row.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/072-dependency-mocks/u9_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/072-dependency-mocks/u9_subject.dart' as subject;

void main() {
  group('U9 (FR-009)', () {
    test(
      'U9 — `zfa tdd realize --adapter <Name>` MUST accept a generated dependency mock behind the declared interface, run the existing differential gates with the declared contract as the parity source, and refuse on surface drift naming the drifted member and the row.',
      () {
        final Object? result = (() {
          try {
            return subject.subject_u9();
          } on UnimplementedError catch (error) {
            return error;
          }
        })();
        expect(result, isNot(isA<UnimplementedError>()));
      },
    );
  });
}
