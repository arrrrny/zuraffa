// Tests for the RefactorAction model and the CycleEntry refactor extension
// (spec 048-tdd-refactor, T002 + T003; behaviors U8, U9, U10).
//
// U10 (existing red/green rendering byte-compatible) is asserted by
// continuing to pass the existing cycle_entry_test.dart suite unchanged.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/cycle_entry.dart';
import 'package:zuraffa/src/plugins/tdd/models/refactor_action.dart';

void main() {
  group('RefactorAction (T002)', () {
    test('captures name, command, exitCode, filesChanged, output', () {
      const action = RefactorAction(
        name: 'format',
        command: 'dart format lib/',
        exitCode: 0,
        filesChanged: ['lib/foo.dart', 'lib/bar.dart'],
        output: 'Formatted lib/foo.dart lib/bar.dart',
      );
      expect(action.name, 'format');
      expect(action.command, 'dart format lib/');
      expect(action.exitCode, 0);
      expect(action.filesChanged, ['lib/foo.dart', 'lib/bar.dart']);
      expect(action.output, 'Formatted lib/foo.dart lib/bar.dart');
    });

    test('a pass that changed no files records filesChanged: []', () {
      const action = RefactorAction(
        name: 'build',
        command: 'zfa build',
        exitCode: 0,
        filesChanged: [],
        output: 'nothing to do',
      );
      expect(action.filesChanged, isEmpty);
    });

    test('every RefactorOutcome is distinct and round-trips by name', () {
      expect(
        RefactorOutcome.values.toSet().length,
        RefactorOutcome.values.length,
      );
      for (final v in RefactorOutcome.values) {
        expect(RefactorOutcome.values.byName(v.name), same(v));
      }
    });

    test('RefactorOutcome has exactly the five contract values', () {
      expect(RefactorOutcome.values.map((v) => v.label).toList()..sort(), [
        'clean',
        'not-green',
        'refactored',
        'regression',
        'runner-error',
      ]);
    });
  });

  group('CycleLogEntry refactor extension (T003)', () {
    test(
      'U8: a refactor entry renders the refactor label and actions block',
      () {
        final entry = CycleLogEntry(
          behaviorId: '048-refactor',
          kind: CycleEntryKind.refactor,
          runnerCommand: 'dart test',
          exitCode: 0,
          capturedOutput: 'All tests passed!',
          sourceCriterion: 'FR-007',
          testPath: 'test/plugins/tdd/',
          timestamp: '2026-08-30T12:00:00.000Z',
          refactorActions: const [
            RefactorAction(
              name: 'format',
              command: 'dart format lib/',
              exitCode: 0,
              filesChanged: ['lib/a.dart'],
              output: 'Formatted lib/a.dart',
            ),
            RefactorAction(
              name: 'fix',
              command: 'dart fix --apply lib/',
              exitCode: 0,
              filesChanged: [],
              output: 'Nothing to fix!',
            ),
          ],
        );
        final md = entry.toMarkdown();
        expect(md, contains('## Cycle: 048-refactor (refactor)'));
        expect(md, contains('- kind: refactor'));
        expect(md, contains('actions:'));
        expect(md, contains('- action: format'));
        expect(md, contains('  command: `dart format lib/`'));
        expect(md, contains('  exit: 0'));
        expect(md, contains('  changed: lib/a.dart'));
        expect(md, contains('- action: fix'));
        expect(md, contains('  changed: (none)'));
      },
    );

    test(
      'U9: refactor entries may omit classification without assertion failure',
      () {
        expect(
          () => CycleLogEntry(
            behaviorId: 'r',
            kind: CycleEntryKind.refactor,
            runnerCommand: 'cmd',
            exitCode: 0,
            capturedOutput: 'ok',
            sourceCriterion: 'FR-007',
            testPath: 'test/x',
            timestamp: '2026-08-30T12:00:00.000Z',
          ),
          returnsNormally,
        );
      },
    );

    test(
      'U9: red entries still require classification (assert relaxed only for '
      'non-red kinds)',
      () {
        expect(
          () => CycleLogEntry(
            behaviorId: 'r',
            kind: CycleEntryKind.red,
            runnerCommand: 'cmd',
            exitCode: 1,
            capturedOutput: 'out',
            sourceCriterion: 'FR-007',
            testPath: 'test/x',
            timestamp: '2026-08-30T12:00:00.000Z',
          ),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test('U10: existing red entry rendering stays byte-compatible '
        '(no regression from 046 contract)', () {
      final red = CycleLogEntry(
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
      final md = red.toMarkdown();
      // The exact contract fields, in order, as pinned by 046 U15.
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
        expect(idx, greaterThan(last), reason: 'red byte-compat: $md');
        last = idx;
      }
      // No actions block on red entries.
      expect(md, isNot(contains('actions:')));
    });

    test('U10: existing green entry rendering stays byte-compatible '
        '(no classification line, no actions block)', () {
      final green = CycleLogEntry(
        behaviorId: 'U3',
        kind: CycleEntryKind.green,
        runnerCommand: 'flutter test',
        exitCode: 0,
        capturedOutput: 'All tests passed',
        sourceCriterion: 'FR-007',
        testPath: 'test/foo_test.dart',
        timestamp: '2026-08-30T09:15:00.000Z',
      );
      final md = green.toMarkdown();
      expect(md, contains('## Cycle: U3 (green)'));
      expect(md, contains('- kind: green'));
      expect(md, isNot(contains('classification')));
      expect(md, isNot(contains('actions:')));
    });

    test('a clean no-op refactor entry writes the no-op marker', () {
      final entry = CycleLogEntry(
        behaviorId: '048-refactor',
        kind: CycleEntryKind.refactor,
        runnerCommand: 'dart test',
        exitCode: 0,
        capturedOutput: 'All tests passed!',
        sourceCriterion: 'FR-008',
        testPath: 'test/plugins/tdd/',
        timestamp: '2026-08-30T12:00:00.000Z',
        refactorActions: const [],
        isNoOp: true,
      );
      final md = entry.toMarkdown();
      expect(md, contains('- no-op: true'));
      expect(md, contains('## Cycle: 048-refactor (refactor)'));
      // No actions block at all on a clean no-op.
      expect(md, isNot(contains('actions:')));
    });
  });
}
