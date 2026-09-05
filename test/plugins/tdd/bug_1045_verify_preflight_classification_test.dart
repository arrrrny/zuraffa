// Bug #1045 — `preflightFileResultFromProcess` maps ANY non-zero preflight
// exit to `PreflightResult.red`, surfacing `gate: preflight_red` — the
// auditor's "the suite is honestly red before mutation" verdict. But a
// non-zero exit can also mean the test file FAILED TO LOAD/COMPILE:
// infrastructure, never an honest red by the plugin's own red taxonomy
// (spec 046 verify-red: red must be an assertion-level failure).
//
// The auditor already makes this distinction for TIME (a preflight
// timeout is NOT_ASSESSED, bug #742). Load/compile failures are the same
// class of infrastructure verdict, just failing faster. Reporting them
// as `preflight_red` misleads downstream tooling in the WRONG direction —
// the suite may be green under the correct runner (observed in the wild:
// zik_zak 006-login-skin, green 16/16 under flutter test, reported red).
//
// Test tier: FAST (pure classification — no processes).
//
// Contract pinned here (remediation, minimal):
//   1. exit 0 → green (unchanged).
//   2. exit != 0 + load/compile signature (`Failed to load`,
//      `compilation failed`) → load failure → `gate: not_assessed` with a
//      `--> fix:` reason. Load markers WIN over the terminal
//      `Some tests failed.` line: a child whose file failed to load
//      prints BOTH.
//   3. exit != 0 + assertion signature (`Some tests failed` / `[E]`
//      without load markers) → `preflight_red` (unchanged honest red).
//   4. exit != 0 with NO recognizable signature → NOT_ASSESSED — never an
//      invented red.
//   5. The fail-fast loop propagates the class: a mid-scope load failure
//      yields a load-failure phase verdict, not a red.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_auditor.dart';

void main() {
  group('unit — preflightFileResultFromProcess classification (#1045)', () {
    test('exit 0 is green — unchanged', () {
      final result = preflightFileResultFromProcess(
        exitCode: 0,
        output: '00:00 +3: All tests passed!\n',
      );
      expect(result.isGreen, isTrue);
      expect(result.failedToLoad, isFalse);
    });

    test('a Failed to load child is a load failure — infrastructure, '
        'never preflight_red', () {
      final result = preflightFileResultFromProcess(
        exitCode: 253,
        output:
            'Failed to load "test/tdd/a1_test.dart": \n'
            'lib/src/presentation/login_view.dart:1:8: Error: Not found\n'
            '00:00 +0 -1: Some tests failed.\n',
      );
      expect(result.isGreen, isFalse);
      expect(result.failedToLoad, isTrue);
    });

    test('a compilation failed child (flutter test signature) is a load '
        'failure too', () {
      final result = preflightFileResultFromProcess(
        exitCode: 254,
        output:
            'lib/main.dart:1:1: Error: Widget library not found.\n'
            'Compilation failed\n',
      );
      expect(result.failedToLoad, isTrue);
    });

    test('a genuine assertion red stays preflight_red — "Some tests '
        'failed" WITHOUT load markers', () {
      final result = preflightFileResultFromProcess(
        exitCode: 1,
        output:
            '00:00 +0: loading test/tdd/a1_test.dart\n'
            '00:00 +0 -1: A1 — the counter increments [E]\n'
            '  Expected: 1\n'
            '    Actual: 0\n'
            '00:01 +0 -1: Some tests failed.\n',
      );
      expect(result.isGreen, isFalse);
      expect(result.failedToLoad, isFalse, reason: 'an honest red');
    });

    test('an unrecognizable non-zero output is NOT a red — honest unknown', () {
      final result = preflightFileResultFromProcess(exitCode: 1, output: '');
      expect(result.isGreen, isFalse);
      expect(result.failedToLoad, isTrue, reason: 'never invent a red');
    });

    test('load markers win over the terminal "Some tests failed." line '
        '(a load-failure child prints both)', () {
      final result = preflightFileResultFromProcess(
        exitCode: 1,
        output:
            'Failed to load "test/tdd/a1_test.dart": import not found\n'
            '00:00 +0 -1: Some tests failed.\n',
      );
      expect(result.failedToLoad, isTrue);
    });
  });

  group('unit — the fail-fast loop propagates the load-failure class '
      '(#1045)', () {
    test('PreflightResult.loadFailure carries the infrastructure flag and '
        'is not green', () {
      final result = PreflightResult.loadFailure(
        exitCode: 253,
        output: 'Failed to load "test/tdd/a2_test.dart"',
        ranTestPaths: const ['test/tdd/a1_test.dart', 'test/tdd/a2_test.dart'],
      );
      expect(result.isGreen, isFalse);
      expect(result.failedToLoad, isTrue);
      expect(result.timedOut, isFalse);
      expect(result.ranTestPaths, hasLength(2));
    });
  });
}
