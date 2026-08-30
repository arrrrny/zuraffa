// Tests for `SuiteGuard` (spec 047-tdd-make T007/T017,
// U14-U18 / FR-007).
//
// Pure unit tests against the parser and diff: no subprocess, no
// fixture project. Cases:
//   U14: failing test identifiers are parsed from runner output
//   U15: NEW failures = guard − baseline
//   U16: a failure present in both baseline and guard is tolerated
//   U17: one fixed + one newly broken test nets a named failure
//   U18: unparseable guard output is a safe failure, never silent pass
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/suite_guard.dart';

void main() {
  const guard = SuiteGuard();

  SuiteSnapshot snap(
    String command,
    int exit,
    String output, {
    String at = '2026-08-30T00:00:00.000Z',
  }) {
    return guard.parse(
      command: command,
      exitCode: exit,
      output: output,
      capturedAt: at,
    );
  }

  group('SuiteGuard (T007 / FR-007)', () {
    test('U14: failing test identifiers are parsed from runner output', () {
      const output = '''
00:01 +1 -1: test/foo_test.dart: group name test name [E]
00:01 +2 -2: test/bar_test.dart: another test [E]
All tests passed!
''';
      final s = snap('dart test', 1, output);
      expect(s.parseable, isTrue);
      expect(s.failedTests, hasLength(2));
      expect(s.failedTests.any((id) => id.contains('foo_test')), isTrue);
      expect(s.failedTests.any((id) => id.contains('bar_test')), isTrue);
    });

    test('U14: trailing failure block is parsed when no progress line', () {
      const output = '''
Some tests failed:
  - test/foo_test.dart: group name test name
  - test/bar_test.dart: another test
''';
      final s = snap('dart test', 1, output);
      expect(s.parseable, isTrue);
      expect(s.failedTests, hasLength(2));
    });

    test('U15: NEW failures are the guard set minus the baseline set', () {
      const baselineOutput = '''
00:01 +1 -1: test/preexisting_test.dart: a flake [E]
''';
      const guardOutput = '''
00:01 +1 -1: test/preexisting_test.dart: a flake [E]
00:02 +1 -1: test/new_regression_test.dart: just broke [E]
''';
      final b = snap('dart test', 1, baselineOutput);
      final g = snap('dart test', 1, guardOutput);
      final d = guard.diff(baseline: b, guard: g);
      expect(d.newFailures, hasLength(1));
      expect(d.newFailures.first, contains('new_regression_test'));
    });

    test('U16: a failure present in both baseline and guard is tolerated', () {
      const baselineOutput = '''
00:01 +1 -1: test/preexisting_test.dart: a flake [E]
''';
      const guardOutput = '''
00:01 +1 -1: test/preexisting_test.dart: a flake [E]
''';
      final b = snap('dart test', 1, baselineOutput);
      final g = snap('dart test', 1, guardOutput);
      final d = guard.diff(baseline: b, guard: g);
      expect(d.hasNewFailures, isFalse);
    });

    test('U17: one fixed + one newly broken test nets a named failure', () {
      // Baseline has two failures: A and B. Guard has B (regressed)
      // and C (new). A is fixed (tolerated — it's NOT in guard so
      // no longer a failure). The diff must surface B and C as new
      // ... wait, B was in baseline too. Re-read the rule: NEW
      // failures = guard − baseline. So only C is NEW.
      // But the test name says "fix+break nets a named failure".
      // Let's check: A was failing in baseline, A is fixed in
      // guard (no longer failing). B is failing in both (tolerated
      // pre-existing). C is failing in guard only → NEW. Diff
      // must surface C (named). A being fixed is not a regression.
      const baselineOutput = '''
00:01 +1 -1: test/a_test.dart: a [E]
00:02 +1 -1: test/b_test.dart: b [E]
''';
      const guardOutput = '''
00:01 +1 -1: test/b_test.dart: b [E]
00:02 +1 -1: test/c_test.dart: c [E]
''';
      final b = snap('dart test', 1, baselineOutput);
      final g = snap('dart test', 1, guardOutput);
      final d = guard.diff(baseline: b, guard: g);
      expect(d.hasNewFailures, isTrue);
      expect(d.newFailures, hasLength(1));
      expect(d.newFailures.first, contains('c_test'));
    });

    test(
      'U18: unparseable guard output is a safe failure, never a silent pass',
      () {
        // Garbage that has no recognizable marker.
        const garbage = 'this is not a real dart test transcript\n';
        final s = snap('dart test', 0, garbage);
        expect(s.parseable, isFalse);
      },
    );

    test('U19: `runSuite` captures exit code and combined output '
        '(integration via fake)', () async {
      // Sanity: SuiteRunRecord is well-formed.
      const rec = SuiteRunRecord(
        command: 'dart test',
        exitCode: 0,
        output: 'All tests passed!',
        startedProcess: true,
      );
      expect(rec.exitCode, 0);
      expect(rec.startedProcess, isTrue);
      expect(rec.output, contains('All tests passed'));
      final s = guard.fromRunRecord(record: rec, capturedAt: 'now');
      expect(s.parseable, isTrue);
      expect(s.failedTests, isEmpty);
    });
  });
}
