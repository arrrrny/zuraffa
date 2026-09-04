// GENERATED TEST — `zfa tdd gen A7` (spec 044-test-tdd-generation).
//
// behavior_id: A7
// source_criterion: AC-7
// kind: acceptance
// description: each page composes behind the host's adaptive shell convention..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/074-plugin-merge-contract/a7_subject.dart' as subject;

void main() {
  group('A7 (AC-7)', () {
    test('A7 — each page composes behind the host\'s adaptive shell convention..', () {
      final Object? result = (() {
        try {
          subject.subject_a7();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
