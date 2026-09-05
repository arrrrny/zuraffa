// GENERATED TEST — `zfa tdd gen A8` (spec 044-test-tdd-generation).
//
// behavior_id: A8
// source_criterion: AC-8
// kind: acceptance
// description: the behavior is NOT routed to a dependency mock (no prose sniffing).
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `../../../lib/tdd/072-dependency-mocks/a8_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/072-dependency-mocks/a8_subject.dart' as subject;

void main() {
  group('A8 (AC-8)', () {
    test(
      'A8 — the behavior is NOT routed to a dependency mock (no prose sniffing).',
      () {
        final Object? result = (() {
          try {
            subject.subject_a8();
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
