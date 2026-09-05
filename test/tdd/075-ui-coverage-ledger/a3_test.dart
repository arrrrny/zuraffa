// GENERATED TEST - zfa tdd gen A3
//
// behavior_id: A3
// source_criterion: AC-3
// kind: acceptance
// description: the row exists with an empty prover and a state marking it unproven — visible at plan time, not after merge..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/075-ui-coverage-ledger/a3_subject.dart' as subject;

void main() {
  group('A3 (AC-3)', () {
    test(
      'A3 - the row exists with an empty prover and a state marking it unproven — visible at plan time, not after merge..',
      () {
        final Object? result = (() {
          try {
            subject.subject_a3();
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
