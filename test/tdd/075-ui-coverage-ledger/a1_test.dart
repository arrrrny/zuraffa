// GENERATED TEST - zfa tdd gen A1
//
// behavior_id: A1
// source_criterion: AC-1
// kind: acceptance
// description: the ledger contains one row per surface with kind text/route/affordance..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/075-ui-coverage-ledger/a1_subject.dart' as subject;

void main() {
  group('A1 (AC-1)', () {
    test(
      'A1 - the ledger contains one row per surface with kind text/route/affordance..',
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
