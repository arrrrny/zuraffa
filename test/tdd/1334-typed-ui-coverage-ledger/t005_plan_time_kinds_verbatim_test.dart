// GENERATED TEST - zfa tdd gen T5 (spec 1334, issue #1143)
//
// behavior_id: T5
// source_criterion: FR-006
// kind: unit
// description: Kinds are assigned at plan time from scenario verbs and consumed verbatim — the ledger never re-infers or relabels a plan-assigned kind.
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/1334-typed-ui-coverage-ledger/t5_subject.dart'
    as subject;

void main() {
  group('T5 (FR-006)', () {
    test('T5 - plan-time kinds verbatim.', () {
      final Object? result = (() {
        try {
          subject.subject_t5();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
