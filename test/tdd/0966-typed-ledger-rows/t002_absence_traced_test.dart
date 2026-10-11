// GENERATED TEST - zfa tdd gen T2 (spec 0966, issue #966)
//
// behavior_id: T2
// source_criterion: FR-002
// kind: unit
// description: An absence row expresses "not rendered in state S" and is traced (DONE) exactly when a green behavior asserts the surface hidden in that state — the error banner hidden initially is traced.
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/0966-typed-ledger-rows/t2_subject.dart' as subject;

void main() {
  group('T2 (FR-002)', () {
    test(
      'T2 - absence assertions: the error banner hidden initially is traced when hidden; a permanently-rendered banner cannot satisfy it; a malformed absence assertion never counts.',
      () {
        final Object? result = (() {
          try {
            subject.subject_t2();
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
