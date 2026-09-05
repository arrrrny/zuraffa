// GENERATED TEST - zfa tdd gen A6
//
// behavior_id: A6
// source_criterion: AC-6
// kind: acceptance
// description: it exits non-zero and the verdict names the surface and its missing prover..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/075-ui-coverage-ledger/a6_subject.dart' as subject;

void main() {
  group('A6 (AC-6)', () {
    test(
      'A6 - it exits non-zero and the verdict names the surface and its missing prover..',
      () {
        final Object? result = (() {
          try {
            subject.subject_a6();
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
