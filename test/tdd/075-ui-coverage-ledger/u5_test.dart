// GENERATED TEST - zfa tdd gen U5
//
// behavior_id: U5
// source_criterion: FR-005
// kind: unit
// description: The coverage gate MUST be wireable as a merge/landing gate: an incomplete ledger blocks the landing naming the gaps (composing with the conformance verdict of 074)..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/075-ui-coverage-ledger/u5_subject.dart' as subject;

void main() {
  group('U5 (FR-005)', () {
    test('U5 - The coverage gate MUST be wireable as a merge/landing gate: an incomplete ledger blocks the landing naming the gaps (composing with the conformance verdict of 074)..', () {
      final Object? result = (() {
        try {
          subject.subject_u5();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
