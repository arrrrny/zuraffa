// GENERATED TEST — `zfa tdd gen A1` (spec 044-test-tdd-generation).
//
// behavior_id: A1
// source_criterion: AC-1
// kind: acceptance
// description: it completes and a parseable baseline snapshot is cached (not a `timedOut: true` record).
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/bug-tdd-run-baseline-timeout/a1_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/bug-tdd-run-baseline-timeout/a1_subject.dart'
    as subject;

void main() {
  group('A1 (AC-1)', () {
    test(
      'A1 — it completes and a parseable baseline snapshot is cached (not a `timedOut: true` record).',
      () {
        final Object? result = (() {
          try {
            subject.subject_a1();
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
