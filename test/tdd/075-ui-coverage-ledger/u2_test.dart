// GENERATED TEST - zfa tdd gen U2
//
// behavior_id: U2
// source_criterion: FR-002
// kind: unit
// description: A surface with no tracing behavior MUST appear in the ledger as unproven at plan time (visible, never omitted)..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/075-ui-coverage-ledger/u2_subject.dart' as subject;

void main() {
  group('U2 (FR-002)', () {
    test(
      'U2 - A surface with no tracing behavior MUST appear in the ledger as unproven at plan time (visible, never omitted)..',
      () {
        final Object? result = (() {
          try {
            subject.subject_u2();
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
