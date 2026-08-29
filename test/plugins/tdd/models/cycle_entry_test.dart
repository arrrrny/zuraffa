// Tests for the CycleLogEntry model (spec 041-tdd-setup-plugin, U6-U7).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/cycle_entry.dart';

void main() {
  group('CycleLogEntry', () {
    test('red entry renders all required fields', () {
      final entry = CycleLogEntry(
        behaviorId: 'A1',
        kind: CycleEntryKind.red,
        runnerCommand: 'flutter test test/foo_test.dart',
        exitCode: 1,
        capturedOutput: 'Expected: a value <> null\nActual: null',
        classification: FailureClass.assertionFailure,
      );
      final md = entry.toMarkdown();
      expect(md, contains('A1'));
      expect(md, contains('red'));
      expect(md, contains('assertionFailure'));
      expect(md, contains('flutter test test/foo_test.dart'));
      expect(md, contains('exit: 1'));
      expect(md, contains('Expected: a value <> null'));
    });

    test('green entry renders without classification', () {
      final entry = CycleLogEntry(
        behaviorId: 'U3',
        kind: CycleEntryKind.green,
        runnerCommand: 'flutter test',
        exitCode: 0,
        capturedOutput: 'All tests passed',
      );
      final md = entry.toMarkdown();
      expect(md, contains('green'));
      expect(md, contains('U3'));
      expect(md, isNot(contains('classification')));
    });

    test('red entry without classification is rejected', () {
      expect(
        () => CycleLogEntry(
          behaviorId: 'A1',
          kind: CycleEntryKind.red,
          runnerCommand: 'cmd',
          exitCode: 1,
          capturedOutput: 'out',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('FailureClass distinguishes the four classes', () {
      expect(
        FailureClass.assertionFailure,
        isNot(equals(FailureClass.compileError)),
      );
      expect(FailureClass.compileError, isNot(equals(FailureClass.loadError)));
      expect(
        FailureClass.loadError,
        isNot(equals(FailureClass.unexpectedGreen)),
      );
    });
  });
}
