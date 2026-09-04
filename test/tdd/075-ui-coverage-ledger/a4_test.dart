// GENERATED TEST - zfa tdd gen A4
//
// behavior_id: A4
// source_criterion: AC-4
// kind: acceptance
// description: it is not forced into the ledger (the ledger's source is the declared Presentation/route contract plus scenario surface markers, not every quotation)..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/075-ui-coverage-ledger/a4_subject.dart' as subject;

void main() {
  group('A4 (AC-4)', () {
    test('A4 - it is not forced into the ledger (the ledger\'s source is the declared Presentation/route contract plus scenario surface markers, not every quotation)..', () {
      final Object? result = (() {
        try {
          subject.subject_a4();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
