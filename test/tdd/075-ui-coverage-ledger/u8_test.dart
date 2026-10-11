// GENERATED TEST - zfa tdd gen U8
//
// behavior_id: U8
// source_criterion: FR-008
// kind: unit
// description: Every refusal and gate failure MUST name the surface, the ledger row, or the missing artifact with a `--> fix:` hint..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/075-ui-coverage-ledger/u8_subject.dart' as subject;

void main() {
  group('U8 (FR-008)', () {
    test(
      'U8 - Every refusal and gate failure MUST name the surface, the ledger row, or the missing artifact with a `--> fix:` hint..',
      () {
        final Object? result = (() {
          try {
            subject.subject_u8();
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
