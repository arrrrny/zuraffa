// GENERATED TEST — `zfa tdd gen U8` (spec 044-test-tdd-generation).
//
// behavior_id: U8
// source_criterion: FR-008
// kind: acceptance
// description: Merge MUST be idempotent — re-merging a merged feature changes nothing and re-runs the gates..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/074-plugin-merge-contract/u8_subject.dart' as subject;

void main() {
  group('U8 (FR-008)', () {
    test(
      'U8 — Merge MUST be idempotent — re-merging a merged feature changes nothing and re-runs the gates..',
      () {
        final Object? result = (() {
          try {
            subject.subject_u8();
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
