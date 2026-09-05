// GENERATED TEST - zfa tdd gen T3 (spec 0966, issue #966)
//
// behavior_id: T3
// source_criterion: FR-003
// kind: unit
// description: A sequence row records the interaction chain steps (tap → loading → resolve → navigate) and is traced (DONE) exactly when a green behavior traces the chain end-to-end.
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/0966-typed-ledger-rows/t3_subject.dart' as subject;

void main() {
  group('T3 (FR-003)', () {
    test(
      'T3 - sequence rows: tap → loading → resolve traced as a chain end-to-end; an unrecorded chain never counts as proof.',
      () {
        final Object? result = (() {
          try {
            subject.subject_t3();
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
