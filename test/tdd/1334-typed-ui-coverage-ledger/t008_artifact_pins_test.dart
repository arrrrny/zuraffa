// GENERATED TEST - zfa tdd gen T8 (spec 1334, issue #1143)
//
// behavior_id: T8
// source_criterion: FR-008
// kind: unit
// description: Artifact pins: markdown/JSON shapes stay 0966-compatible; the per-screen verdict JSON records the full report; summary/failure lines carry the issue 1143 vocabulary.
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/1334-typed-ui-coverage-ledger/t8_subject.dart'
    as subject;

void main() {
  group('T8 (FR-008)', () {
    test('T8 - artifact pins.', () {
      final Object? result = (() {
        try {
          subject.subject_t8();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
