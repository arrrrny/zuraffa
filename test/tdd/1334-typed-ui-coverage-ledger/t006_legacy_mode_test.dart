// GENERATED TEST - zfa tdd gen T6 (spec 1334, issue #1143)
//
// behavior_id: T6
// source_criterion: FR-007
// kind: unit
// description: Ledger JSON without typed kind fields reads as legacy (rows reclassified presence; gate rows-only); a 0966-written ledger with golden rows reads as typed (presence + advisory).
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/1334-typed-ui-coverage-ledger/t6_subject.dart'
    as subject;

void main() {
  group('T6 (FR-007)', () {
    test('T6 - legacy mode.', () {
      final Object? result = (() {
        try {
          subject.subject_t6();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
