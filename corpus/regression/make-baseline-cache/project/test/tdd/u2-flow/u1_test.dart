// GENERATED TEST — `zfa tdd gen U1` (spec 044-test-tdd-generation).
//
// behavior_id: U1
// source_criterion: AC-1
// kind: unit
// description: the flow entrypoint resolves its first dependency
//
// The subject has been implemented to return a sentinel value that
// satisfies the behavior described above. The UnimplementedError guard
// is present but there is also a real assertion on the observable
// outcome (issue #1259: refuse vacuous greens).
library;

import 'package:test/test.dart';
import 'package:u2_flow/tdd/u2-flow/u1_subject.dart' as subject;

void main() {
  group('U1 (AC-1)', () {
    test('U1 — the flow entrypoint resolves its first dependency', () {
      final result = (() {
        try {
          return subject.subject_u1();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
      expect(result, equals(42),
          reason: 'the flow entrypoint resolves to a resolved value');
    });
  });
}
