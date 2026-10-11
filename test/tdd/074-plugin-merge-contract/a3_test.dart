// GENERATED TEST — `zfa tdd gen A3` (spec 044-test-tdd-generation).
//
// behavior_id: A3
// source_criterion: AC-3
// kind: acceptance
// description: the only changes outside the feature's own artifacts are regenerated barrels (no manual wiring)..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/074-plugin-merge-contract/a3_subject.dart'
    as subject;

void main() {
  group('A3 (AC-3)', () {
    test(
      'A3 — the only changes outside the feature\'s own artifacts are regenerated barrels (no manual wiring)..',
      () {
        final Object? result = (() {
          try {
            subject.subject_a3();
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
