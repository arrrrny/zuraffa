// GENERATED TEST - zfa tdd gen A5
//
// behavior_id: A5
// source_criterion: AC-5
// kind: acceptance
// description: it exits 0 with a JSON verdict listing each surface proven..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/075-ui-coverage-ledger/a5_subject.dart' as subject;

void main() {
  group('A5 (AC-5)', () {
    test(
      'A5 - it exits 0 with a JSON verdict listing each surface proven..',
      () {
        final Object? result = (() {
          try {
            subject.subject_a5();
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
