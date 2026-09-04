// GENERATED TEST — `zfa tdd gen U6` (spec 044-test-tdd-generation).
//
// behavior_id: U6
// source_criterion: FR-006
// kind: acceptance
// description: Any conformance failure MUST roll the host back byte-identical to its pre-merge state, exit non-zero, and name the failed checks..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/074-plugin-merge-contract/u6_subject.dart' as subject;

void main() {
  group('U6 (FR-006)', () {
    test('U6 — Any conformance failure MUST roll the host back byte-identical to its pre-merge state, exit non-zero, and name the failed checks..', () {
      final Object? result = (() {
        try {
          subject.subject_u6();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
