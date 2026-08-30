// Tests for the CycleLogEntry model (spec 041-tdd-setup-plugin, U6-U7;
// extended by spec 046-tdd-verify-red, U15-U16 / T002).
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
        sourceCriterion: 'FR-007',
        testPath: 'test/foo_test.dart',
        timestamp: '2026-08-30T09:15:00.000Z',
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
        sourceCriterion: 'FR-007',
        testPath: 'test/foo_test.dart',
        timestamp: '2026-08-30T09:15:00.000Z',
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
          sourceCriterion: 'FR-007',
          testPath: 'test/foo_test.dart',
          timestamp: '2026-08-30T09:15:00.000Z',
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

  group('U15 — 8-field contract entry (spec 046, FR-006)', () {
    test(
      'red entry emits the contract fields in the fixed order '
      '(behavior, kind, classification, criterion, test, command, exit, at, output)',
      () {
        final entry = CycleLogEntry(
          behaviorId: 'B-001',
          kind: CycleEntryKind.red,
          runnerCommand: 'dart test /tmp/x_test.dart --plain-name "returns 42"',
          exitCode: 1,
          capturedOutput: 'Expected: <2>\n  Actual: <1>',
          classification: FailureClass.assertionFailure,
          sourceCriterion: 'FR-006',
          testPath: 'test/tdd/b_001_test.dart',
          timestamp: '2026-08-30T09:15:00.000Z',
        );
        final md = entry.toMarkdown();
        // Fixed order per contracts (spec 046 US1.AC2 / tasks T002).
        final orderedLines = [
          '- behavior: B-001',
          '- kind: red',
          '- classification: assertionFailure',
          '- criterion: FR-006',
          '- test: test/tdd/b_001_test.dart',
          '- command: `dart test /tmp/x_test.dart --plain-name "returns 42"`',
          '- exit: 1',
          '- at: 2026-08-30T09:15:00.000Z',
          '- output:',
        ];
        var last = -1;
        for (final line in orderedLines) {
          final idx = md.indexOf(line);
          expect(
            idx,
            greaterThan(last),
            reason:
                '"$line" must appear after the previous contract field; '
                'got:\n$md',
          );
          last = idx;
        }
        // The captured failure output is inside a fenced block.
        expect(md, contains('Expected: <2>'));
      },
    );

    test('entry header names the behavior and kind', () {
      final entry = CycleLogEntry(
        behaviorId: 'B-001',
        kind: CycleEntryKind.red,
        runnerCommand: 'cmd',
        exitCode: 1,
        capturedOutput: 'out',
        classification: FailureClass.assertionFailure,
        sourceCriterion: 'FR-006',
        testPath: 'test/tdd/b_001_test.dart',
        timestamp: '2026-08-30T09:15:00.000Z',
      );
      expect(entry.toMarkdown(), contains('## Cycle: B-001 (red)'));
    });
  });

  group('U16 — widened FailureClass (spec 046, FR-004/FR-006)', () {
    test('includes skipped and runnerError alongside the original four', () {
      expect(
        FailureClass.values.map((v) => v.name),
        containsAll(<String>['skipped', 'runnerError']),
      );
    });

    test('every value round-trips through its name', () {
      for (final value in FailureClass.values) {
        expect(FailureClass.values.byName(value.name), same(value));
      }
    });
  });
}
