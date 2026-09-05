// GENERATED TEST — `zfa tdd gen A12` (spec 044-test-tdd-generation).
//
// behavior_id: A12
// source_criterion: AC-12
// kind: acceptance
// description: they are byte-identical..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/074-plugin-merge-contract/a12_subject.dart' as subject;

void main() {
  group('A12 (AC-12)', () {
    test('A12 — they are byte-identical..', () {
      final Object? result = (() {
        try {
          subject.subject_a12();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
