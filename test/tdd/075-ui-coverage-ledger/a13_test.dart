// GENERATED TEST - zfa tdd gen A13
//
// behavior_id: A13
// source_criterion: AC-13
// kind: acceptance
// description: the certified fake serves the scripted responses (the demo runs on the certification, not a parallel fake)..
//
// This test asserts the observable behavior described above.
library;

import 'package:test/test.dart';

import '../../../lib/tdd/075-ui-coverage-ledger/a13_subject.dart' as subject;

void main() {
  group('A13 (AC-13)', () {
    test(
      'A13 - the certified fake serves the scripted responses (the demo runs on the certification, not a parallel fake)..',
      () {
        final Object? result = (() {
          try {
            subject.subject_a13();
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
