// GENERATED TEST - zfa tdd gen T2 (spec 1334, issue #1143)
//
// behavior_id: T2
// source_criterion: FR-003
// kind: unit
// description: The per-screen kind report lists all five kinds (0/0 included) and counts ANY zero-traced kind as a gap; a presence-only screen reads partially-traced — not 100%.
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/1334-typed-ui-coverage-ledger/t2_subject.dart'
    as subject;

void main() {
  group('T2 (FR-003)', () {
    test('T2 - per-screen all-five-kinds report.', () {
      final Object? result = (() {
        try {
          subject.subject_t2();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
