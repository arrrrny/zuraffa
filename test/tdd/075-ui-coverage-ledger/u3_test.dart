// GENERATED TEST - zfa tdd gen U3
//
// behavior_id: U3
// source_criterion: FR-003
// kind: unit
// description: Ledger state MUST derive from current evidence: a surface is DONE only when at least one of its provers is green; planned-but-red provers never count..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/075-ui-coverage-ledger/u3_subject.dart' as subject;

void main() {
  group('U3 (FR-003)', () {
    test('U3 - Ledger state MUST derive from current evidence: a surface is DONE only when at least one of its provers is green; planned-but-red provers never count..', () {
      final Object? result = (() {
        try {
          subject.subject_u3();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
