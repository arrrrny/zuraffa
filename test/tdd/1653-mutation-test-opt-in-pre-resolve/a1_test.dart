// GENERATED TEST — `zfa tdd gen A1` (spec 044-test-tdd-generation).
//
// behavior_id: A1
// source_criterion: AC-1
// kind: acceptance
// description: dev_dependencies gain the testing baseline
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `package:zuraffa/tdd/1653-mutation-test-opt-in-pre-resolve/a1_subject.dart` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder).
//
// zfa:tdd: A1:hand — hand step completed before first red certification
// (issue #1411). The acceptance lane's guard-only fallback (issue #1512)
// cannot carry AC-1, so the scenario call is awaited and the observable
// outcome is asserted OUTSIDE the guard capture, on the dev-dependency map
// the subject recorded from a real default `zfa tdd init` run
// (issue #1653).
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/1653-mutation-test-opt-in-pre-resolve/a1_subject.dart'
    as subject;

void main() {
  group('A1 (AC-1)', () {
    test('A1 — dev_dependencies gain the testing baseline', () async {
      Object? result;
      try {
        await subject.subject_a1();
        result = null;
      } on UnimplementedError catch (error) {
        result = error;
      }
      // The generated guard: still rejects an UnimplementedError stub.
      expect(result, isNot(isA<UnimplementedError>()));

      // zfa:tdd: A1:hand (issue #1411) — the AC-1 observable outcome,
      // asserted OUTSIDE the capture.
      expect(
        subject.a1ObservedDevDeps,
        isNotEmpty,
        reason: 'default `zfa tdd init` must ADD the testing baseline '
            'dev_dependencies (AC-1)',
      );
      expect(
        subject.a1ObservedDevDeps,
        isNot(contains('mutation_test')),
        reason: 'issue #1653: mutation_test is opt-in (--mutation) and must '
            'never ride the default baseline',
      );
    });
  });
}
