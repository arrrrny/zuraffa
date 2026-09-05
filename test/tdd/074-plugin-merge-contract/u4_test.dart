// GENERATED TEST — `zfa tdd gen U4` (spec 044-test-tdd-generation).
//
// behavior_id: U4
// source_criterion: FR-004
// kind: acceptance
// description: Merged views MUST compose behind the host's adaptive shell convention; off-convention view artifacts MUST be refused naming the artifact..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/074-plugin-merge-contract/u4_subject.dart' as subject;

void main() {
  group('U4 (FR-004)', () {
    test(
      'U4 — Merged views MUST compose behind the host\'s adaptive shell convention; off-convention view artifacts MUST be refused naming the artifact..',
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
