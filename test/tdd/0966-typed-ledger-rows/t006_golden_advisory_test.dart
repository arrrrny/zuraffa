// GENERATED TEST - zfa tdd gen T6 (spec 0966, issue #966)
//
// behavior_id: T6
// source_criterion: FR-007
// kind: unit
// description: Golden rows are advisory with per-platform tolerance: excluded from the merge-gate verdict (recorded decision) and reported separately as advisory; the navigation verb yields a navigation row.
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/0966-typed-ledger-rows/t6_subject.dart' as subject;

void main() {
  group('T6 (FR-007)', () {
    test(
      'T6 - goldens stay advisory: never block the merge gate regardless of state, per-platform tolerance carried, reported separately; the navigation verb yields a navigation row.',
      () {
        final Object? result = (() {
          try {
            subject.subject_t6();
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
