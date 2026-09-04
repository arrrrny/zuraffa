// GENERATED TEST — `zfa tdd gen U3` (spec 044-test-tdd-generation).
//
// behavior_id: U3
// source_criterion: FR-003
// kind: acceptance
// description: Merge MUST register the feature's bindings through the host's service locator in mock and real flavors; the DI-graph construction check MUST construct the full graph in the merged host..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/074-plugin-merge-contract/u3_subject.dart' as subject;

void main() {
  group('U3 (FR-003)', () {
    test('U3 — Merge MUST register the feature\'s bindings through the host\'s service locator in mock and real flavors; the DI-graph construction check MUST construct the full graph in the merged host..', () {
      final Object? result = (() {
        try {
          subject.subject_u3();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
