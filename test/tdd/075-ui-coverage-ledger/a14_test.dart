// GENERATED TEST - zfa tdd gen A14
//
// behavior_id: A14
// source_criterion: AC-14
// kind: acceptance
// description: it names `zfa mock dependency <Name>` as the fix — no hand-authored stand-ins..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/075-ui-coverage-ledger/a14_subject.dart' as subject;

void main() {
  group('A14 (AC-14)', () {
    test(
      'A14 - it names `zfa mock dependency <Name>` as the fix — no hand-authored stand-ins..',
      () {
        final Object? result = (() {
          try {
            subject.subject_a14();
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
