// GENERATED TEST — `zfa tdd gen A1` (spec 044-test-tdd-generation).
//
// behavior_id: A1
// source_criterion: AC-1
// kind: acceptance
// description: the host's route barrel is regenerated to include the feature's routes..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/074-plugin-merge-contract/a1_subject.dart'
    as subject;

void main() {
  group('A1 (AC-1)', () {
    test(
      'A1 — the host\'s route barrel is regenerated to include the feature\'s routes..',
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
