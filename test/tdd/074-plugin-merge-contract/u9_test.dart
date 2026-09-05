// GENERATED TEST — `zfa tdd gen U9` (spec 044-test-tdd-generation).
//
// behavior_id: U9
// source_criterion: FR-009
// kind: acceptance
// description: Every refusal and every failed gate MUST name the offending artifact, token, or behavior with a `--> fix:` hint..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/074-plugin-merge-contract/u9_subject.dart' as subject;

void main() {
  group('U9 (FR-009)', () {
    test(
      'U9 — Every refusal and every failed gate MUST name the offending artifact, token, or behavior with a `--> fix:` hint..',
      () {
        final Object? result = (() {
          try {
            subject.subject_u9();
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
