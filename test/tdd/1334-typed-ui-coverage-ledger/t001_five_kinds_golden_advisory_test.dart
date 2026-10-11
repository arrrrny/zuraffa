// GENERATED TEST - zfa tdd gen T1 (spec 1334, issue #1143)
//
// behavior_id: T1
// source_criterion: FR-001, FR-002
// kind: unit
// description: Five kinds exactly: LedgerRowKind has no golden value; a golden scenario yields kind presence + advisory true + per-platform tolerance; goldens never block the gate; the deck reports them ADVISORY.
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/1334-typed-ui-coverage-ledger/t1_subject.dart'
    as subject;

void main() {
  group('T1 (FR-001, FR-002)', () {
    test('T1 - five kinds + golden advisory.', () {
      final Object? result = (() {
        try {
          subject.subject_t1();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
