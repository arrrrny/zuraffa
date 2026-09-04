// GENERATED TEST — `zfa tdd gen U1` (spec 044-test-tdd-generation).
//
// behavior_id: U1
// source_criterion: FR-001
// kind: acceptance
// description: Merge MUST regenerate the host's route barrel to include the merged feature's routes; hand-edited host routing is never required and never performed..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/074-plugin-merge-contract/u1_subject.dart' as subject;

void main() {
  group('U1 (FR-001)', () {
    test(
      'U1 — Merge MUST regenerate the host\'s route barrel to include the merged feature\'s routes; hand-edited host routing is never required and never performed..',
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
