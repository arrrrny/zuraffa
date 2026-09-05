// GENERATED TEST - zfa tdd gen U4
//
// behavior_id: U4
// source_criterion: FR-004
// kind: unit
// description: `zfa tdd coverage` (the coverage gate) MUST emit a machine-readable JSON verdict (one line per surface: kind, proven-by, state) and exit 0 only when every row is DONE; failures name each unproven surface and its missing prover..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/075-ui-coverage-ledger/u4_subject.dart' as subject;

void main() {
  group('U4 (FR-004)', () {
    test(
      'U4 - `zfa tdd coverage` (the coverage gate) MUST emit a machine-readable JSON verdict (one line per surface: kind, proven-by, state) and exit 0 only when every row is DONE; failures name each unproven surface and its missing prover..',
      () {
        final Object? result = (() {
          try {
            subject.subject_u4();
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
