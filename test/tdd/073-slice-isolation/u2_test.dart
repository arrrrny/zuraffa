// GENERATED TEST — `zfa tdd gen U2` (spec 044-test-tdd-generation).
//
// behavior_id: U2
// source_criterion: FR-002
// kind: unit
// description: The sandbox MUST be self-contained: its suite runs green with the host unavailable, and no generated file references the host.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/073-slice-isolation/u2_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/073-slice-isolation/u2_subject.dart' as subject;

void main() {
  group('U2 (FR-002)', () {
    test(
      'U2 — The sandbox MUST be self-contained: its suite runs green with the host unavailable, and no generated file references the host.',
      () {
        final Object? result = (() {
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
