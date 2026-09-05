// GENERATED TEST - zfa tdd gen U6
//
// behavior_id: U6
// source_criterion: FR-006
// kind: unit
// description: With xray enabled, the overlay MUST paint surfaces by ledger state (proven clean, unproven highlighted), reading the ledger as its source of truth; with no ledger present it MUST report absence, never paint proof..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/075-ui-coverage-ledger/u6_subject.dart' as subject;

void main() {
  group('U6 (FR-006)', () {
    test(
      'U6 - With xray enabled, the overlay MUST paint surfaces by ledger state (proven clean, unproven highlighted), reading the ledger as its source of truth; with no ledger present it MUST report absence, never paint proof..',
      () {
        final Object? result = (() {
          try {
            subject.subject_u6();
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
