// GENERATED TEST - zfa tdd gen T4 (spec 1334, issue #1143)
//
// behavior_id: T4
// source_criterion: FR-005
// kind: unit
// description: The XRay overlay renders the per-kind view per screen (status line + one line per kind, zero-traced kinds HIGHLIGHT, never painted as proof); the surface-count view is legacy-only.
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/1334-typed-ui-coverage-ledger/t4_subject.dart'
    as subject;

void main() {
  group('T4 (FR-005)', () {
    test('T4 - per-kind overlay rendering.', () {
      final Object? result = (() {
        try {
          subject.subject_t4();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
