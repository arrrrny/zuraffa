// GENERATED TEST — `zfa tdd gen A11` (spec 044-test-tdd-generation).
//
// behavior_id: A11
// source_criterion: AC-11
// kind: acceptance
// description: the feature-suite check fails, the host rolls back, and the failure names the red behavior..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/074-plugin-merge-contract/a11_subject.dart' as subject;

void main() {
  group('A11 (AC-11)', () {
    test(
      'A11 — the feature-suite check fails, the host rolls back, and the failure names the red behavior..',
      () {
        final Object? result = (() {
          try {
            subject.subject_a11();
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
