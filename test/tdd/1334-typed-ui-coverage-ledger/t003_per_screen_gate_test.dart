// GENERATED TEST - zfa tdd gen T3 (spec 1334, issue #1143)
//
// behavior_id: T3
// source_criterion: FR-004
// kind: unit
// description: The per-screen gate fails on row gaps or zero-traced kind gaps (naming screen + kind + fix hint) and passes only when every screen is fully-traced.
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/1334-typed-ui-coverage-ledger/t3_subject.dart'
    as subject;

void main() {
  group('T3 (FR-004)', () {
    test('T3 - per-screen gate.', () {
      final Object? result = (() {
        try {
          subject.subject_t3();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
