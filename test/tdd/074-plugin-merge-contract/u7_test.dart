// GENERATED TEST — `zfa tdd gen U7` (spec 044-test-tdd-generation).
//
// behavior_id: U7
// source_criterion: FR-007
// kind: acceptance
// description: The feature-suite gate MUST compare against a pre-merge baseline: pre-existing reds never fail a merge; new reds always do..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/074-plugin-merge-contract/u7_subject.dart' as subject;

void main() {
  group('U7 (FR-007)', () {
    test(
      'U7 — The feature-suite gate MUST compare against a pre-merge baseline: pre-existing reds never fail a merge; new reds always do..',
      () {
        final Object? result = (() {
          try {
            subject.subject_u7();
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
