// GENERATED TEST - zfa tdd gen A8
//
// behavior_id: A8
// source_criterion: AC-8
// kind: acceptance
// description: the surfaces it would prove read NOT-DONE (green is the only proof)..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/075-ui-coverage-ledger/a8_subject.dart' as subject;

void main() {
  group('A8 (AC-8)', () {
    test(
      'A8 - the surfaces it would prove read NOT-DONE (green is the only proof)..',
      () {
        final Object? result = (() {
          try {
            subject.subject_a8();
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
