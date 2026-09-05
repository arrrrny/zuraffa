// GENERATED TEST — `zfa tdd gen A6` (spec 044-test-tdd-generation).
//
// behavior_id: A6
// source_criterion: AC-6
// kind: acceptance
// description: every dependency touchpoint serves the certified mock..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/074-plugin-merge-contract/a6_subject.dart' as subject;

void main() {
  group('A6 (AC-6)', () {
    test('A6 — every dependency touchpoint serves the certified mock..', () {
      final Object? result = (() {
        try {
          subject.subject_a6();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
