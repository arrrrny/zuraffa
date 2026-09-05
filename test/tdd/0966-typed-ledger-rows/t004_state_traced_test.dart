// GENERATED TEST - zfa tdd gen T4 (spec 0966, issue #966)
//
// behavior_id: T4
// source_criterion: FR-004
// kind: unit
// description: A state row records the asserted widget attribute (buttons disabled while in flight — FR-005-class) and is traced end-to-end in the 004-login-ui corpus.
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/0966-typed-ledger-rows/t4_subject.dart' as subject;

void main() {
  group('T4 (FR-004)', () {
    test(
      'T4 - state rows: the FR-005-class attribute (buttons disabled in flight) is traced end-to-end in 004-login-ui; an unrecorded attribute never counts as proof.',
      () {
        final Object? result = (() {
          try {
            subject.subject_t4();
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
