// Tests for the CycleLogEntry model (spec 041-tdd-setup-plugin, U6-U7;
// extended by spec 046-tdd-verify-red, U15-U16 / T002;
// extended by spec 047-tdd-make, U21-U22 / T003).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/cycle_entry.dart';
import 'package:zuraffa/src/plugins/tdd/models/generation_plan.dart';

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

    test('green entry with omitted evidence renders (none) placeholders', () {
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
      expect(md, contains('- generation:\n  (none)'));
      expect(md, contains('- suite: baseline=0 guard=0 new=(none)'));
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

  group('U15 — 8 evidence fields plus structural kind (spec 046, FR-006)', () {
    test(
      'red entry emits all nine serialized fields in the fixed order '
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

  group('U21-U22 — green evidence extensions (spec 047-tdd-make, T003)', () {
    test('U21: a green entry renders the generation: block listing each '
        'step\'s command and exit code in execution order', () {
      final entry = CycleLogEntry(
        behaviorId: 'B-001',
        kind: CycleEntryKind.green,
        runnerCommand: 'dart test /x_test.dart --plain-name "x"',
        exitCode: 0,
        capturedOutput: 'All tests passed!',
        sourceCriterion: 'FR-007',
        testPath: '/x_test.dart',
        timestamp: '2026-08-30T00:00:00.000Z',
        generationSteps: [
          GenerationStep(
            command: 'zfa entity create User',
            exitCode: 0,
            output: 'created',
            purpose: 'create entity User',
          ),
          GenerationStep(
            command: 'zfa build',
            exitCode: 0,
            output: 'built',
            purpose: 'build generated code',
          ),
        ],
        suiteBaselineFailures: 0,
        suiteGuardFailures: 0,
        suiteNewFailures: const [],
      );
      final md = entry.toMarkdown();
      expect(md, contains('- kind: green'));
      expect(md, contains('- generation:'));
      // Steps in execution order.
      final firstCmdIdx = md.indexOf('zfa entity create User');
      final secondCmdIdx = md.indexOf('zfa build');
      expect(firstCmdIdx, greaterThan(0));
      expect(secondCmdIdx, greaterThan(firstCmdIdx));
      // Exit codes recorded.
      expect(md, contains('exit: 0'));
      expect(md, contains('purpose: create entity User'));
      expect(md, contains('purpose: build generated code'));
    });

    test('U22: a green entry renders the suite: line with baseline and '
        'guard counts', () {
      final entry = CycleLogEntry(
        behaviorId: 'B-002',
        kind: CycleEntryKind.green,
        runnerCommand: 'dart test /x_test.dart --plain-name "x"',
        exitCode: 0,
        capturedOutput: 'All tests passed!',
        sourceCriterion: 'FR-007',
        testPath: '/x_test.dart',
        timestamp: '2026-08-30T00:00:00.000Z',
        generationSteps: const [],
        suiteBaselineFailures: 1,
        suiteGuardFailures: 1,
        suiteNewFailures: const [],
      );
      final md = entry.toMarkdown();
      expect(md, contains('- suite: baseline=1 guard=1 new=(none)'));
      expect(md, contains('- generation:\n  (none)'));
      expect(md, isNot(contains('evidence missing')));
    });

    test(
      'U22b: a green entry with NEW failures lists them in the suite: line',
      () {
        final entry = CycleLogEntry(
          behaviorId: 'B-003',
          kind: CycleEntryKind.green,
          runnerCommand: 'dart test /x_test.dart --plain-name "x"',
          exitCode: 0,
          capturedOutput: 'All tests passed!',
          sourceCriterion: 'FR-007',
          testPath: '/x_test.dart',
          timestamp: '2026-08-30T00:00:00.000Z',
          generationSteps: const [],
          suiteBaselineFailures: 0,
          suiteGuardFailures: 2,
          suiteNewFailures: const [
            'test/foo_test.dart: a',
            'test/bar_test.dart: b',
          ],
        );
        final md = entry.toMarkdown();
        expect(md, contains('- suite: baseline=0 guard=2 new='));
        expect(md, contains('foo_test'));
        expect(md, contains('bar_test'));
      },
    );
  });
}
