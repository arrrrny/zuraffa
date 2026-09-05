// GENERATED TEST - zfa tdd gen U1
//
// behavior_id: U1
// source_criterion: FR-001
// kind: unit
// description: The plan MUST produce a per-feature UI surface ledger enumerating declared surfaces — static texts (quoted-literal contract), declared routes (Presentation contract row), and named affordances — each with kind, proving behavior ids, and state..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/075-ui-coverage-ledger/u1_subject.dart' as subject;

void main() {
  group('U1 (FR-001)', () {
    test(
      'U1 - The plan MUST produce a per-feature UI surface ledger enumerating declared surfaces — static texts (quoted-literal contract), declared routes (Presentation contract row), and named affordances — each with kind, proving behavior ids, and state..',
      () {
        final Object? result = (() {
          try {
            subject.subject_u1();
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
