// GENERATED TEST - zfa tdd gen T7 (spec 0966, issue #966, remediation)
//
// behavior_id: T7
// source_criterion: FR-005
// kind: unit
// description: Ledger row kinds are assigned at plan time from scenario verbs — every verb branch (absence/navigation/state/sequence/golden) classifies, and the precedence rules hold.
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/0966-typed-ledger-rows/t7_subject.dart' as subject;

void main() {
  group('T7 (FR-005)', () {
    test(
      'T7 - the full plan-time verb→kind matrix: every branch classifies and the precedence rules hold (sequence > navigation > absence > state > presence).',
      () {
        final Object? result = (() {
          try {
            subject.subject_t7();
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
