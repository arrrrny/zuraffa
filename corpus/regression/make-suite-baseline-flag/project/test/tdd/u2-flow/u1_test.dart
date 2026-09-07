// GENERATED TEST — pre-seeded for corpus differential (issue #1259).
// Subject returns 42; test has a real assertion beyond the guard.
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
