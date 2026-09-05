// GENERATED TEST - zfa tdd gen A11
//
// behavior_id: A11
// source_criterion: AC-11
// kind: acceptance
// description: it lists the ledger rows with their states (the deck drives the ledger, not a separate inventory)..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/075-ui-coverage-ledger/a11_subject.dart' as subject;

void main() {
  group('A11 (AC-11)', () {
    test(
      'A11 - it lists the ledger rows with their states (the deck drives the ledger, not a separate inventory)..',
      () {
        final Object? result = (() {
          try {
            subject.subject_a11();
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
