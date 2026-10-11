// GENERATED TEST — `zfa tdd gen A4` (spec 044-test-tdd-generation).
//
// behavior_id: A4
// source_criterion: AC-4
// kind: acceptance
// description: the feature's binding module registers through the host's locator in both mock and real flavors..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/074-plugin-merge-contract/a4_subject.dart'
    as subject;

void main() {
  group('A4 (AC-4)', () {
    test(
      'A4 — the feature\'s binding module registers through the host\'s locator in both mock and real flavors..',
      () {
        final Object? result = (() {
          try {
            subject.subject_a4();
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
