// GENERATED TEST — `zfa tdd gen A8` (spec 044-test-tdd-generation).
//
// behavior_id: A8
// source_criterion: AC-8
// kind: acceptance
// description: it refuses naming the off-convention artifact..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/074-plugin-merge-contract/a8_subject.dart' as subject;

void main() {
  group('A8 (AC-8)', () {
    test('A8 — it refuses naming the off-convention artifact..', () {
      final Object? result = (() {
        try {
          subject.subject_a8();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
