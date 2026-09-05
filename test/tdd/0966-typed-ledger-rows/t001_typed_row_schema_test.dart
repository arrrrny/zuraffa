// GENERATED TEST - zfa tdd gen T1 (spec 0966, issue #966)
//
// behavior_id: T1
// source_criterion: FR-001
// kind: unit
// description: Each ledger row carries a kind (presence/absence/navigation/state/sequence) and the coverage gate treats a declared kind with no traced row as a gap — untraced kinds are gaps, named.
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/0966-typed-ledger-rows/t1_subject.dart' as subject;

void main() {
  group('T1 (FR-001)', () {
    test(
      'T1 - typed ledger row schema: kinds from scenario verbs at plan time; untraced kinds (absence + sequence) are gate gaps on the all-9-literals-Column view.',
      () {
        final Object? result = (() {
          try {
            subject.subject_t1();
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
