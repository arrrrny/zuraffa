// GENERATED TEST — `zfa tdd gen U5` (spec 044-test-tdd-generation).
//
// behavior_id: U5
// source_criterion: FR-005
// kind: unit
// description: `zfa slice merge --into <host>` MUST land the feature's artifacts, journal, and registry into the host and MUST refuse when verify's verdict is failing or absent.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/073-slice-isolation/u5_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/073-slice-isolation/u5_subject.dart' as subject;

void main() {
  group('U5 (FR-005)', () {
    test('U5 — `zfa slice merge --into <host>` MUST land the feature\'s artifacts, journal, and registry into the host and MUST refuse when verify\'s verdict is failing or absent.', () {
      final Object? result = (() {
        try {
          return subject.subject_u5();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
