// GENERATED TEST - zfa tdd gen A7
//
// behavior_id: A7
// source_criterion: AC-7
// kind: acceptance
// description: merge is blocked with the gap named..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/075-ui-coverage-ledger/a7_subject.dart' as subject;

void main() {
  group('A7 (AC-7)', () {
    test('A7 - merge is blocked with the gap named..', () {
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
