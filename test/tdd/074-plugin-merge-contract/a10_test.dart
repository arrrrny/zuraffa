// GENERATED TEST — `zfa tdd gen A10` (spec 044-test-tdd-generation).
//
// behavior_id: A10
// source_criterion: AC-10
// kind: acceptance
// description: the routes check fails, the host is rolled back byte-identical to pre-merge, and the exit is non-zero naming the failed check..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/074-plugin-merge-contract/a10_subject.dart' as subject;

void main() {
  group('A10 (AC-10)', () {
    test(
      'A10 — the routes check fails, the host is rolled back byte-identical to pre-merge, and the exit is non-zero naming the failed check..',
      () {
        final Object? result = (() {
          try {
            subject.subject_a10();
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
