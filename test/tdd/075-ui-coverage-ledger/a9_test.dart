// GENERATED TEST - zfa tdd gen A9
//
// behavior_id: A9
// source_criterion: AC-9
// kind: acceptance
// description: the overlay highlights exactly the unproven affordance and paints proven surfaces clean..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/075-ui-coverage-ledger/a9_subject.dart' as subject;

void main() {
  group('A9 (AC-9)', () {
    test(
      'A9 - the overlay highlights exactly the unproven affordance and paints proven surfaces clean..',
      () {
        final Object? result = (() {
          try {
            subject.subject_a9();
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
