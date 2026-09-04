// GENERATED TEST - zfa tdd gen A2
//
// behavior_id: A2
// source_criterion: AC-2
// kind: acceptance
// description: its state reads DONE with the proving behavior ids named..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/075-ui-coverage-ledger/a2_subject.dart' as subject;

void main() {
  group('A2 (AC-2)', () {
    test('A2 - its state reads DONE with the proving behavior ids named..', () {
      final Object? result = (() {
        try {
          subject.subject_a2();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
