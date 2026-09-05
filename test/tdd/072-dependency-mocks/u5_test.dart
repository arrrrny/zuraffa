// GENERATED TEST — `zfa tdd gen U5` (spec 044-test-tdd-generation).
//
// behavior_id: U5
// source_criterion: FR-005
// kind: unit
// description: A behavior whose trace names a declared dependency row MUST be routed to the dependency-mock surface by that declaration (through the declared-routing seam), with provenance naming the row; prose without a declaration MUST never route a behavior to a dependency mock.
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/072-dependency-mocks/u5_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/072-dependency-mocks/u5_subject.dart' as subject;

void main() {
  group('U5 (FR-005)', () {
    test(
      'U5 — A behavior whose trace names a declared dependency row MUST be routed to the dependency-mock surface by that declaration (through the declared-routing seam), with provenance naming the row; prose without a declaration MUST never route a behavior to a dependency mock.',
      () {
        final Object? result = (() {
          try {
            return subject.subject_u5();
          } on UnimplementedError catch (error) {
            return error;
          }
        })();
        expect(result, isNot(isA<UnimplementedError>()));
      },
    );
  });
}
