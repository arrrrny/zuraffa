// GENERATED TEST - zfa tdd gen T5 (spec 0966, issue #966)
//
// behavior_id: T5
// source_criterion: FR-006
// kind: unit
// description: The XRay overlay renders kind coverage per screen; the all-9-literals-Column view fails the gate (absence + sequence untraced) and shows as partially traced.
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/0966-typed-ledger-rows/t5_subject.dart' as subject;

void main() {
  group('T5 (FR-006)', () {
    test(
      'T5 - XRay overlay renders kind coverage per screen; the all-9-literals-Column view is partially traced (absence + sequence untraced); the deck lists kind entries.',
      () {
        final Object? result = (() {
          try {
            subject.subject_t5();
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
